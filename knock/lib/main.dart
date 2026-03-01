import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _supabaseUrl = 'https://ovpxeuowzwjrvhkulldr.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92cHhldW93endqcnZoa3VsbGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDI0ODEsImV4cCI6MjA4NjkxODQ4MX0.obWpaemtnKatOmDVveR5xczThnjMi3l9QECE_Qu7H_k';

const _accentColors = [
  Color(0xFFE0E0E0),
  Color(0xFFBDBDBD),
  Color(0xFF9E9E9E),
  Color(0xFF757575),
  Color(0xFFCCCCCC),
  Color(0xFFB0B0B0),
];

// -- Design tokens --
const _primaryColor = Color(0xFFE0E0E0); // silver
const _cardColor = Color(0xFF121212);
const _cardColorAlt = Color(0xFF1E1E1E);
const _cardColorElevated = Color(0xFF2C2C2C);
const _borderColor = Color(0xFF2C2C2C);
const _subtleTextColor = Color(0xFF757575);
const _mutedTextColor = Color(0xFF9E9E9E);


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SupabaseClient get _sb => Supabase.instance.client;
String? get _uid => _sb.auth.currentUser?.id;

// For showing notifications when FCM message arrives (foreground + heads-up)
const AndroidNotificationChannel _knockChannel = AndroidNotificationChannel(
  'knock_channel',
  'Knocks',
  description: 'Incoming knock notifications',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Color _colorForIndex(int i) => _accentColors[i % _accentColors.length];

String _generateUserId() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random();
  final code = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
  return 'KNCK-$code';
}

String _formatTimestamp(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays > 0) return '${diff.inDays}d';
  if (diff.inHours > 0) return '${diff.inHours}h';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m';
  return 'now';
}

// ---------------------------------------------------------------------------
// Knock relationship data
// ---------------------------------------------------------------------------

class KnockRelationship {
  KnockRelationship({
    required this.friendId,
    this.myCustomKnockText,
    this.theirCustomKnockText,
    this.isInitial = true,
    this.knockHistory = const [],
  });
  final String friendId;
  final String? myCustomKnockText;
  final String? theirCustomKnockText;
  bool isInitial;
  List<Map<String, dynamic>> knockHistory;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is configured for Android/iOS only; skip on web to avoid blank screen in Edge/browser
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initLocalNotifications();
  }
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  runApp(const KnockApp());
}

Future<void> _initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: android);
  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (_) {},
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_knockChannel);
}

// FCM background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM: Handling a background message: ${message.messageId}');
}

/// Saves the current FCM token to the user's profile in Supabase (call when signed in).
/// Used by onTokenRefresh and after initial permission grant. Skips on web/emulator (no token).
Future<void> saveFcmTokenToSupabase() async {
  if (kIsWeb) {
    debugPrint('FCM: Skipping save (web)');
    return;
  }
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    debugPrint('FCM: Skipping save - no logged-in user');
    return;
  }
  final uid = user.id;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('FCM: No token available (common on emulator)');
      return;
    }
    await _sb.from('profiles').update({'fcm_token': token}).eq('id', uid);
    debugPrint('FCM: Token saved to Supabase for user $uid');
  } catch (e) {
    debugPrint('FCM: Save token error: $e');
  }
}

/// Requests notification permission, gets FCM token, and saves to Supabase.
/// Call after successful login and when home screen loads. Works only on real devices
/// (emulators typically do not provide a valid FCM token).
Future<void> requestFcmPermissionAndSaveToken() async {
  if (kIsWeb) {
    debugPrint('FCM: Skipping (web)');
    return;
  }
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    debugPrint('FCM: No current user, skipping permission request');
    return;
  }
  try {
    final messaging = FirebaseMessaging.instance;
    debugPrint('FCM: Requesting notification permission...');
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM: Permission denied');
      return;
    }
    if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('FCM: Permission provisional (iOS)');
    }
    debugPrint('FCM: Permission granted, getting token...');
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('FCM: No token (emulator or unsupported environment)');
      return;
    }
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _sb.from('profiles').update({'fcm_token': token}).eq('id', uid);
    debugPrint('FCM: Token saved to profiles.fcm_token for user $uid');
  } catch (e) {
    debugPrint('FCM: requestFcmPermissionAndSaveToken error: $e');
  }
}

// ---------------------------------------------------------------------------
// FCM foreground handler widget
// ---------------------------------------------------------------------------

class FcmHandler extends StatefulWidget {
  final Widget child;
  const FcmHandler({required this.child, super.key});

  @override
  State<FcmHandler> createState() => _FcmHandlerState();
}

class _FcmHandlerState extends State<FcmHandler> {
  @override
  void initState() {
    super.initState();
    _initFcm();
  }

  Future<void> _initFcm() async {
    if (kIsWeb) return; // FCM not set up for web; use mobile for push
    // Permission + get token + save are done after login in HomeScreen (requestFcmPermissionAndSaveToken).
    // Here we only set up listeners for foreground messages and token refresh.
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      debugPrint('FCM: Token refreshed');
      saveFcmTokenToSupabase();
    });
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM: Foreground message: ${message.messageId}');
      _showForegroundNotification(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM: App opened from notification: ${message.messageId}');
    });
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? 'Knock';
    final body = notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        'New knock';
    final details = AndroidNotificationDetails(
      _knockChannel.id,
      _knockChannel.name,
      channelDescription: _knockChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
    );
    await _localNotifications.show(
      message.hashCode % 100000,
      title,
      body,
      NotificationDetails(android: details),
    );
  }


  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class KnockApp extends StatelessWidget {
  const KnockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FcmHandler(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          surface: _cardColor,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
            fontSize: 22,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _cardColorElevated,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
        home: const AppGate(),
      ),
    );
  }
}

// ===========================================================================
//  KNOCK LOGO – custom-drawn brand mark
// ===========================================================================

class KnockLogo extends StatelessWidget {
  final double size;
  const KnockLogo({super.key, this.size = 110});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

// ===========================================================================
//  SPLASH SCREEN - animated logo on launch
// ===========================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Run auth + profile check with no artificial delay
    bool hasProfile = false;
    try {
      if (_uid == null) {
        try {
          await _sb.auth.signInAnonymously();
        } catch (_) {}
      }
      if (_uid != null) {
        final existing = await _sb
            .from('profiles')
            .select()
            .eq('id', _uid!)
            .maybeSingle();
        hasProfile = existing != null;
      }
    } catch (e) {
      debugPrint('Splash auth error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            hasProfile ? const HomeScreen() : SetupScreen(onComplete: () {}),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Unified splash: logo centered + app name at the bottom (Instagram-style).
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Logo centered on screen
          const Center(
            child: KnockLogo(size: 120),
          ),
          // App name at the bottom
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: Text(
                'KNOCK',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: Color(0xFF757575),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
//  APP GATE - checks if profile exists, shows setup or home
// ===========================================================================

class AppGate extends StatefulWidget {
  const AppGate({super.key});
  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _checking = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_uid != null) {
      await _checkProfile();
      return;
    }
    try {
      await _sb.auth.signInAnonymously();
      if (_uid != null) {
        await _checkProfile();
        return;
      }
    } catch (_) {}
    setState(() {
      _checking = false;
      _hasProfile = false;
    });
  }

  Future<void> _checkProfile() async {
    final uid = _uid;
    if (uid == null) {
      setState(() {
        _checking = false;
        _hasProfile = false;
      });
      return;
    }
    try {
      final existing = await _sb
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      setState(() {
        _checking = false;
        _hasProfile = existing != null;
      });
    } catch (e) {
      debugPrint('Profile check error: $e');
      setState(() {
        _checking = false;
        _hasProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      // Branded loading screen matching the native splash
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Stack(
          children: [
            const Center(child: KnockLogo(size: 120)),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Center(
                child: Text(
                  'KNOCK',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Color(0xFF757575),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_hasProfile) return const HomeScreen();
    return SetupScreen(onComplete: () => setState(() => _hasProfile = true));
  }
}

// ===========================================================================
//  SETUP SCREEN - username, optional avatar, knock ID
// ===========================================================================

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _usernameC = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _generatedId;
  String? _selectedAvatar;
  int _step = 0; // 0 = username, 1 = knock ID card

  Future<void> _submitUsername() async {
    final name = _usernameC.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a username');
      return;
    }
    setState(() => _error = null);
    await _createAccount();
  }

  Future<void> _createAccount() async {
    final name = _usernameC.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_uid == null) {
        final tag = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        final rnd = Random().nextInt(99999).toString().padLeft(5, '0');
        final email = 'knock_${tag}_$rnd@knock.app';
        const pass = 'KnockAutoPass2026!';

        try {
          final res = await _sb.auth.signUp(
            email: email,
            password: pass,
            emailRedirectTo: null,
          );
          if (res.session == null && res.user != null) {
            try {
              await _sb.auth.signInWithPassword(email: email, password: pass);
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('SignUp error: $e');
          try {
            final rnd2 = Random().nextInt(99999).toString().padLeft(5, '0');
            final email2 = 'knock_${tag}_$rnd2@knock.app';
            await _sb.auth.signUp(email: email2, password: pass);
          } catch (_) {}
        }
      }

      final uid = _uid;
      if (uid == null) {
        setState(() {
          _error = 'Could not create account. Check your connection.';
          _loading = false;
        });
        return;
      }

      final userId = _generateUserId();
      final existing = await _sb
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (existing == null) {
        final rndSuffix = Random().nextInt(99999).toString().padLeft(5, '0');
        final insertData = <String, dynamic>{
          'id': uid,
          'username':
              '${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_$rndSuffix',
          'display_name': name,
          'knock_code': userId,
        };
        if (_selectedAvatar != null) {
          insertData['avatar_emoji'] = _selectedAvatar;
        }
        await _sb.from('profiles').insert(insertData);
      } else {
        setState(() {
          _generatedId = existing['knock_code'] as String? ?? userId;
          _step = 1;
          _loading = false;
        });
        return;
      }

      setState(() {
        _generatedId = userId;
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Try again.';
        _loading = false;
      });
      debugPrint('Setup error: $e');
    }
  }

  void _goToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _step == 0
                  ? _buildUsernameStep()
                  : _buildIdCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Column(
      key: const ValueKey('step0'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const KnockLogo(size: 90),
        const SizedBox(height: 28),
        const Text(
          'Welcome to Knock!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick a username to get started',
          style: const TextStyle(fontSize: 16, color: _mutedTextColor),
        ),
        const SizedBox(height: 36),
        TextField(
          controller: _usernameC,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: const TextStyle(
              color: _subtleTextColor,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: _cardColor,
            prefixIcon: const Icon(Icons.person_outline, color: _mutedTextColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _submitUsername,
            style: ElevatedButton.styleFrom(
              backgroundColor: _cardColorElevated,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _borderColor),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'GET MY KNOCK ID',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ],
    );
  }


  Widget _buildIdCard() {
    return Column(
      key: const ValueKey('step2'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _cardColorElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _borderColor),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "You're all set!",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Here's your personal Knock ID.\nShare it with friends to connect!",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: _mutedTextColor, height: 1.5),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              const Text(
                'YOUR KNOCK ID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: _subtleTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _generatedId!,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedId!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Knock ID copied!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy ID'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _goToHome,
            style: ElevatedButton.styleFrom(
              backgroundColor: _cardColorElevated,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _borderColor),
              ),
            ),
            child: const Text(
              'CONTINUE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
//  HOME SCREEN - friends list + incoming knock listener
// ===========================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;
  StreamSubscription? _knockSub;
  RealtimeChannel? _connectionsChannel;
  String? _myKnockId;
  String? _myDisplayName;
  String? _myAvatarEmoji;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFriends();
    _listenForKnocks();
    _listenForConnections();
    // After successful login and when home loads: request permission, get FCM token, save to Supabase (real devices only).
    requestFcmPermissionAndSaveToken();
  }

  @override
  void dispose() {
    _knockSub?.cancel();
    if (_connectionsChannel != null) {
      _sb.removeChannel(_connectionsChannel!);
    }
    super.dispose();
  }

  void _listenForConnections() {
    final uid = _uid;
    if (uid == null) return;
    _connectionsChannel = _sb.channel('connections_realtime_$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'connections',
        callback: (payload) {
          // Reload friends when any connection row involving this user changes
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          final rowUserId = record['user_id'] as String?;
          final rowFriendId = record['friend_id'] as String?;
          if (rowUserId == uid || rowFriendId == uid) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _loadFriends();
            });
          }
        },
      )
      ..subscribe();
  }

  Future<void> _loadProfile() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final row = await _sb
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _myKnockId = row['knock_code'] as String?;
          _myDisplayName = row['display_name'] as String?;
          _myAvatarEmoji = row['avatar_emoji'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Load profile error: $e');
    }
  }

  Future<void> _loadFriends() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('connections')
          .select(
            'friend_id, label, profiles!connections_friend_id_fkey(username, display_name)',
          )
          .eq('user_id', uid);

      final friendList = List<Map<String, dynamic>>.from(rows);
      final friendIds = friendList
          .map((f) => f['friend_id'] as String)
          .toList();

      Map<String, Map<String, dynamic>> lastKnockByFriend = {};
      if (friendIds.isNotEmpty) {
        try {
          final friendSet = friendIds.toSet();
          final sent = await _sb
              .from('knocks')
              .select('receiver_id, message, created_at')
              .eq('sender_id', uid)
              .order('created_at', ascending: false)
              .limit(200);
          final received = await _sb
              .from('knocks')
              .select('sender_id, message, created_at')
              .eq('receiver_id', uid)
              .order('created_at', ascending: false)
              .limit(200);

          for (final k in sent) {
            final fid = k['receiver_id'] as String?;
            if (fid == null || !friendSet.contains(fid)) continue;
            if (!lastKnockByFriend.containsKey(fid)) {
              lastKnockByFriend[fid] = {
                'message': k['message'],
                'created_at': k['created_at'],
                'is_from_me': true,
              };
            }
          }
          for (final k in received) {
            final fid = k['sender_id'] as String?;
            if (fid == null || !friendSet.contains(fid)) continue;
            final existing = lastKnockByFriend[fid];
            final createdAt = DateTime.tryParse(
              k['created_at'] as String? ?? '',
            );
            final existingAt = existing != null
                ? DateTime.tryParse(existing['created_at'] as String? ?? '')
                : null;
            if (existing == null ||
                (createdAt != null &&
                    existingAt != null &&
                    createdAt.isAfter(existingAt))) {
              lastKnockByFriend[fid] = {
                'message': k['message'],
                'created_at': k['created_at'],
                'is_from_me': false,
              };
            }
          }
        } catch (_) {}
      }

      for (final f in friendList) {
        final fid = f['friend_id'] as String;
        final last = lastKnockByFriend[fid];
        f['last_message'] = last?['message'];
        f['last_message_at'] = last?['created_at'];
      }

      setState(() {
        _friends = friendList;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading friends: $e');
      setState(() => _loading = false);
    }
  }

  void _listenForKnocks() {
    final uid = _uid;
    if (uid == null) return;
    _knockSub = _sb
        .from('knocks')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', uid)
        .listen((rows) {
          if (rows.isNotEmpty) {
            final latest = rows.last;
            final createdAt = DateTime.tryParse(latest['created_at'] ?? '');
            if (createdAt != null &&
                DateTime.now().toUtc().difference(createdAt).inSeconds < 5) {
              HapticFeedback.heavyImpact();
              if (mounted) {
                // Look up sender name from friends list
                final senderId = latest['sender_id'] as String?;
                String senderName = 'Someone';
                for (final f in _friends) {
                  if (f['friend_id'] == senderId) {
                    final profile =
                        f['profiles'] as Map<String, dynamic>? ?? {};
                    senderName = profile['display_name'] ??
                        profile['username'] ??
                        'Someone';
                    break;
                  }
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _cardColorElevated,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    content: Text(
                      '$senderName: ${latest['message']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          }
        });
  }

  Future<void> _addFriend() async {
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _borderColor),
          ),
          title: const Text(
            'Add Friend',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter your friend's Knock ID to connect",
                style: TextStyle(color: _mutedTextColor, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: c,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'KNCK-XXXX',
                  hintStyle: const TextStyle(
                    color: _subtleTextColor,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 2,
                  ),
                  filled: true,
                  fillColor: _cardColorAlt,
                  prefixIcon: const Icon(Icons.tag, color: _mutedTextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _mutedTextColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim().toUpperCase()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cardColorElevated,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _borderColor),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (input == null || input.isEmpty) return;

    try {
      final profile = await _sb
          .from('profiles')
          .select()
          .eq('knock_code', input)
          .maybeSingle();

      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No user found with that Knock ID'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      if (profile['id'] == _uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("That's your own ID!"),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      final friendId = profile['id'] as String;
      await _sb.rpc('add_mutual_connection', params: {'friend_id': friendId});

      _loadFriends();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile['display_name'] ?? 'Friend'} added!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _cardColorElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openProfile() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (changed == true) _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final displayInitial = _myDisplayName?.isNotEmpty == true
        ? _myDisplayName![0].toUpperCase()
        : '?';
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text(
          'KNOCK',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _openProfile,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _myDisplayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (_myKnockId != null)
                        Text(
                          _myKnockId!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _subtleTextColor,
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _cardColorAlt,
                    child: Text(
                      _myAvatarEmoji ?? displayInitial,
                      style: TextStyle(
                        fontSize: _myAvatarEmoji != null ? 20 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cardColorElevated,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: _addFriend,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Friend',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _friends.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _loadFriends,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _friends.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final f = _friends[index];
                  final profile = f['profiles'] as Map<String, dynamic>? ?? {};
                  final name =
                      profile['display_name'] ??
                      profile['username'] ??
                      'Unknown';
                  final label = f['label'] ?? 'Friend';
                  final friendId = f['friend_id'] as String;
                  final color = _colorForIndex(index);
                  final lastMsg = f['last_message'] as String?;
                  final lastAtStr = f['last_message_at'] as String?;
                  final lastAt = lastAtStr != null
                      ? DateTime.tryParse(lastAtStr)
                      : null;

                  return _FriendCard(
                    name: name,
                    label: label,
                    friendId: friendId,
                    accentColor: color,
                    lastMessage: lastMsg,
                    lastMessageAt: lastAt,
                    onRemove: () => _confirmRemoveFriend(friendId, name),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _confirmRemoveFriend(String friendId, String name) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _borderColor),
          ),
          title: const Text(
            'Remove friend?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          content: Text(
            'This will remove $name from your friends list.',
            style: const TextStyle(color: _mutedTextColor, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _mutedTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cardColorElevated,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _borderColor),
                ),
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (shouldRemove != true) return;
    await _removeFriend(friendId, name);
  }

  Future<void> _removeFriend(String friendId, String name) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _sb.rpc('remove_mutual_connection', params: {'p_friend_id': friendId});
      setState(() {
        _friends.removeWhere((f) => f['friend_id'] == friendId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $name'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _cardColorElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Remove friend error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing $name: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _borderColor),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: _mutedTextColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No friends yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "Add Friend" and enter their\nKnock ID to connect',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _mutedTextColor),
          ),
          const SizedBox(height: 28),
          if (_myKnockId != null) ...[
            const Text(
              'YOUR KNOCK ID',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: _subtleTextColor,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _myKnockId!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Knock ID copied!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _myKnockId!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: _mutedTextColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
//  PROFILE SCREEN - view/edit profile, avatar, knock ID
// ===========================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameC = TextEditingController();
  String? _knockId;
  String? _avatarEmoji;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final row = await _sb
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _nameC.text = row['display_name'] as String? ?? '';
          _knockId = row['knock_code'] as String?;
          _avatarEmoji = row['avatar_emoji'] as String?;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    if (_nameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name cannot be empty'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{'display_name': _nameC.text.trim()};
      if (_avatarEmoji != null) {
        updates['avatar_emoji'] = _avatarEmoji;
      }
      await _sb.from('profiles').update(updates).eq('id', uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _cardColorElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Profile save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final displayInitial = _nameC.text.isNotEmpty
        ? _nameC.text[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // ---- Avatar ----
            GestureDetector(
              onTap: () {},
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: _cardColorAlt,
                    child: Text(
                      _avatarEmoji ?? displayInitial,
                      style: TextStyle(
                        fontSize: _avatarEmoji != null ? 44 : 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _cardColorElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap an avatar below to change',
              style: TextStyle(fontSize: 13, color: _mutedTextColor),
            ),
            const SizedBox(height: 32),

            // ---- Display name ----
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'DISPLAY NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: _subtleTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameC,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: _cardColor,
                prefixIcon: const Icon(Icons.person_outline, color: _mutedTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ---- Knock ID ----
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'YOUR KNOCK ID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: _subtleTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag, color: _mutedTextColor, size: 20),
                  const SizedBox(width: 10),
                  SelectableText(
                    _knockId ?? '------',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    color: _mutedTextColor,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _knockId ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Knock ID copied!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // ---- Avatar picker ----
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'PROFILE PICTURE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: _subtleTextColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:
                  [
                    {'emoji': '\u{1F468}', 'label': 'Male'},
                    {'emoji': '\u{1F469}', 'label': 'Female'},
                    {'emoji': displayInitial, 'label': 'Custom'},
                  ].map((opt) {
                    final emoji = opt['emoji']!;
                    final label = opt['label']!;
                    final isCustom = label == 'Custom';
                    final selected = _avatarEmoji == emoji;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _avatarEmoji = emoji),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: selected
                                    ? _cardColorElevated
                                    : _cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? Colors.white
                                      : _borderColor,
                                  width: selected ? 2.5 : 1.5,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                emoji,
                                style: TextStyle(
                                  fontSize: isCustom ? 26 : 32,
                                  fontWeight: isCustom
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : _mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friend card
// ---------------------------------------------------------------------------

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.name,
    required this.label,
    required this.friendId,
    required this.accentColor,
    this.lastMessage,
    this.lastMessageAt,
    required this.onRemove,
  });

  final String name;
  final String label;
  final String friendId;
  final Color accentColor;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitle = lastMessage != null && lastMessage!.isNotEmpty
        ? lastMessage!
        : label;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserDetailScreen(
              friendId: friendId,
              name: name,
              label: label,
              accentColor: accentColor,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor, width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: _cardColorAlt,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: _mutedTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.person_remove_alt_1_rounded,
                color: _subtleTextColor,
              ),
              tooltip: 'Remove friend',
              onPressed: onRemove,
            ),
            if (lastMessageAt != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _formatTimestamp(lastMessageAt),
                  style: const TextStyle(fontSize: 12, color: _subtleTextColor),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: _subtleTextColor),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
//  USER DETAIL - send knocks
// ===========================================================================

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({
    super.key,
    required this.friendId,
    required this.name,
    required this.label,
    required this.accentColor,
  });

  final String friendId;
  final String name;
  final String label;
  final Color accentColor;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  List<String> _customKnocks = [];
  final _newKnockC = TextEditingController();
  int _sendingIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchCustomKnocks();
  }

  @override
  void dispose() {
    _newKnockC.dispose();
    super.dispose();
  }

  // ---- Persistence (local SharedPreferences + Supabase sync) ----

  String get _localKey => 'knocks_${widget.friendId}';

  Future<void> _fetchCustomKnocks() async {
    // 1. Load from local storage first (instant)
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_localKey);
    if (local != null && local.isNotEmpty && mounted) {
      setState(() {
        try {
          final decoded = jsonDecode(local);
          if (decoded is List) {
            _customKnocks = decoded.cast<String>();
          }
        } catch (_) {}
      });
    }

    // 2. Also try fetching from Supabase (merge/sync)
    final uid = _uid;
    if (uid == null) return;
    try {
      final conn = await _sb
          .from('connections')
          .select('custom_text')
          .eq('user_id', uid)
          .eq('friend_id', widget.friendId)
          .maybeSingle();
      if (conn == null || !mounted) return;
      final raw = conn['custom_text'] as String?;
      if (raw == null || raw.isEmpty) return;
      List<String> remote = [];
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          remote = decoded.cast<String>();
        } else {
          remote = [raw];
        }
      } catch (_) {
        remote = [raw];
      }
      // If remote has data and local is empty, use remote
      if (remote.isNotEmpty && _customKnocks.isEmpty) {
        setState(() => _customKnocks = remote);
        await prefs.setString(_localKey, jsonEncode(remote));
      }
    } catch (e) {
      debugPrint('Fetch custom knocks from Supabase: $e');
    }
  }

  Future<void> _saveKnocksList() async {
    final encoded = jsonEncode(_customKnocks);

    // 1. Save locally (always works)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, encoded);

    // 2. Sync to Supabase (best effort)
    final uid = _uid;
    if (uid == null) return;
    try {
      await _sb
          .from('connections')
          .update({'custom_text': encoded})
          .eq('user_id', uid)
          .eq('friend_id', widget.friendId);
    } catch (e) {
      debugPrint('Sync custom knocks to Supabase: $e');
    }
  }

  void _addKnock() {
    final text = _newKnockC.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _customKnocks.add(text);
      _newKnockC.clear();
    });
    _saveKnocksList();
  }

  void _removeKnock(int index) {
    final removed = _customKnocks[index];
    setState(() => _customKnocks.removeAt(index));
    _saveKnocksList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$removed" removed'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ---- Send a knock (one-tap) ----

  Future<void> _sendKnock(String message, int tileIndex) async {
    final uid = _uid;
    if (uid == null || message.isEmpty) return;
    setState(() => _sendingIndex = tileIndex);
    HapticFeedback.heavyImpact();
    try {
      await _sb.rpc('send_knock_safe', params: {
        'p_receiver_id': widget.friendId,
        'p_message': message,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text(
                  'Knock sent!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: _cardColorElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Send error: $e');
      final errorStr = e.toString().toLowerCase();
      if (mounted && errorStr.contains('no connection exists')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'This user is no longer in your friends list',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: _cardColorElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _sendingIndex = -1);
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header ----
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'SEND A KNOCK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: _subtleTextColor,
              ),
            ),
          ),

          // ---- Scrollable knock list ----
          Expanded(
            child: _customKnocks.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'No custom knocks yet.\nAdd one below!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: _mutedTextColor,
                          height: 1.6,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: _customKnocks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final msg = _customKnocks[i];
                      final isSending = _sendingIndex == i;
                      return AnimatedScale(
                        scale: isSending ? 1.04 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isSending
                                ? null
                                : () => _sendKnock(msg, i),
                            onLongPress: () => _removeKnock(i),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSending
                                      ? Colors.white
                                      : _borderColor,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.touch_app_rounded,
                                    size: 18,
                                    color: _mutedTextColor,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      msg,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: _subtleTextColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ---- Add knock input ----
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: _cardColor,
              border: Border(
                top: BorderSide(color: _borderColor, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newKnockC,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addKnock(),
                      decoration: InputDecoration(
                        hintText: 'e.g. Drink Water, Take Medicine...',
                        hintStyle: const TextStyle(
                          color: _subtleTextColor,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: _cardColorAlt,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _addKnock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cardColorElevated,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: _borderColor),
                        ),
                      ),
                      child: const Icon(Icons.add_rounded, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
