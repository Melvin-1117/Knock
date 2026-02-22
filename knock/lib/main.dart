import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  runApp(const KnockApp());
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class KnockApp extends StatelessWidget {
  const KnockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const SplashScreen(),
    );
  }
}

// ===========================================================================
//  KNOCK LOGO – custom-drawn brand mark
// ===========================================================================

class KnockLogo extends StatelessWidget {
  final double size;
  const KnockLogo({super.key, this.size = 120});

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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Run auth + profile check in parallel with the splash animation
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

    // Ensure splash shows for at least 2.5 seconds
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            hasProfile ? const HomeScreen() : SetupScreen(onComplete: () {}),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App logo
                const KnockLogo(size: 120),
                const SizedBox(height: 28),
                const Text(
                  'KNOCK',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap into your circle',
                  style: TextStyle(
                    fontSize: 15,
                    color: _mutedTextColor,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
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
  int _step = 0; // 0 = username, 1 = avatar pick, 2 = knock ID card

  Future<void> _submitUsername() async {
    final name = _usernameC.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a username');
      return;
    }
    setState(() {
      _error = null;
      _step = 1; // move to avatar step
    });
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
          _step = 2;
          _loading = false;
        });
        return;
      }

      setState(() {
        _generatedId = userId;
        _step = 2;
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
                  : _step == 1
                  ? _buildAvatarStep()
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
            onPressed: _submitUsername,
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
              'NEXT',
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

  Widget _buildAvatarStep() {
    final displayInitial = _usernameC.text.trim().isNotEmpty
        ? _usernameC.text.trim()[0].toUpperCase()
        : '?';

    // Avatar options: Male, Female, Custom (initial letter)
    final avatarOptions = [
      {'emoji': '\u{1F468}', 'label': 'Male'},
      {'emoji': '\u{1F469}', 'label': 'Female'},
      {'emoji': displayInitial, 'label': 'Custom'},
    ];

    return Column(
      key: const ValueKey('step1'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview avatar
        CircleAvatar(
          radius: 52,
          backgroundColor: _cardColorAlt,
          child: Text(
            _selectedAvatar ?? displayInitial,
            style: TextStyle(
              fontSize: _selectedAvatar != null ? 44 : 38,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hi, ${_usernameC.text.trim()}!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose your profile picture',
          style: TextStyle(fontSize: 15, color: _mutedTextColor),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: avatarOptions.map((opt) {
            final emoji = opt['emoji']!;
            final label = opt['label']!;
            final isCustom = label == 'Custom';
            final selected = _selectedAvatar == emoji;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedAvatar = emoji),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: selected
                            ? _cardColorElevated
                            : _cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : _borderColor,
                          width: selected ? 2.5 : 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emoji,
                        style: TextStyle(
                          fontSize: isCustom ? 30 : 36,
                          fontWeight: isCustom
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? Colors.white : _mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _createAccount,
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
        const SizedBox(height: 12),
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  setState(() => _selectedAvatar = null);
                  _createAccount();
                },
          child: const Text(
            'Skip for now',
            style: TextStyle(
              color: _subtleTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
  StreamSubscription? _connectionsSub;
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
  }

  @override
  void dispose() {
    _knockSub?.cancel();
    _connectionsSub?.cancel();
    super.dispose();
  }

  void _listenForConnections() {
    final uid = _uid;
    if (uid == null) return;
    _connectionsSub = _sb
        .from('connections')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .listen((_) {
          if (mounted) _loadFriends();
        });
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _cardColorElevated,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    content: Text(
                      '\u{1F514} ${latest['message']}',
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
                  );
                },
              ),
            ),
    );
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
  });

  final String name;
  final String label;
  final String friendId;
  final Color accentColor;
  final String? lastMessage;
  final DateTime? lastMessageAt;

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
  List<Map<String, dynamic>> _knockHistory = [];
  List<String> _customKnocks = [];
  final _newKnockC = TextEditingController();
  StreamSubscription? _knockStreamSub;
  int _sendingIndex = -1; // which custom knock tile is animating

  static const _chatBg = Color(0xFF000000);
  static const _senderBubble = Color(0xFF1A1A1A);
  static const _receiverBubble = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _fetchCustomKnocks();
    _listenForKnocks();
  }

  @override
  void dispose() {
    _newKnockC.dispose();
    _knockStreamSub?.cancel();
    super.dispose();
  }

  // ---- Persistence (JSON array in custom_text column) ----

  Future<void> _fetchCustomKnocks() async {
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
      setState(() {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            _customKnocks = decoded.cast<String>();
          } else {
            // backward compat: plain string → wrap in list
            _customKnocks = [raw];
          }
        } catch (_) {
          // Not valid JSON – treat as single legacy string
          _customKnocks = [raw];
        }
      });
    } catch (e) {
      debugPrint('Fetch custom knocks error: $e');
    }
  }

  Future<void> _saveKnocksList() async {
    final uid = _uid;
    if (uid == null) return;
    final encoded = jsonEncode(_customKnocks);
    await _sb
        .from('connections')
        .update({'custom_text': encoded})
        .eq('user_id', uid)
        .eq('friend_id', widget.friendId);
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
    setState(() => _customKnocks.removeAt(index));
    _saveKnocksList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom knock removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---- Listen to incoming knocks ----

  void _listenForKnocks() {
    final uid = _uid;
    if (uid == null) return;
    _knockStreamSub = _sb
        .from('knocks')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', uid)
        .listen((rows) {
          if (mounted) setState(() => _knockHistory = rows);
        });
  }

  // ---- Send a knock (one-tap) ----

  Future<void> _sendKnock(String message, int tileIndex) async {
    final uid = _uid;
    if (uid == null || message.isEmpty) return;
    setState(() => _sendingIndex = tileIndex);
    HapticFeedback.heavyImpact();
    try {
      await _sb.from('knocks').insert({
        'sender_id': uid,
        'receiver_id': widget.friendId,
        'message': message,
      });
    } catch (e) {
      debugPrint('Send error: $e');
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
      backgroundColor: _chatBg,
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
        children: [
          // ---- Knock history (chat bubbles) ----
          Expanded(
            child: _knockHistory.isEmpty
                ? const Center(
                    child: Text(
                      'Send your first knock',
                      style: TextStyle(
                        fontSize: 16,
                        color: _mutedTextColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _knockHistory.length,
                    itemBuilder: (context, i) {
                      final k = _knockHistory[i];
                      final isMe = k['sender_id'] == _uid;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.72,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? _senderBubble
                                    : _receiverBubble,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _borderColor,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                k['message'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ---- Custom knocks panel ----
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _cardColor,
              border: Border(
                top: BorderSide(color: _borderColor, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'CUSTOM KNOCKS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: _subtleTextColor,
                    ),
                  ),
                ),

                // Tiles
                if (_customKnocks.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_customKnocks.length, (i) {
                        final msg = _customKnocks[i];
                        final isSending = _sendingIndex == i;
                        return AnimatedScale(
                          scale: isSending ? 1.08 : 1.0,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _cardColorElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSending
                                        ? Colors.white
                                        : _borderColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.touch_app_rounded,
                                      size: 16,
                                      color: _mutedTextColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      msg,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                if (_customKnocks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Add a custom knock to send with one tap',
                      style: TextStyle(
                        fontSize: 13,
                        color: _subtleTextColor,
                      ),
                    ),
                  ),

                // Add-knock input row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                              borderSide:
                                  const BorderSide(color: _borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: _borderColor),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                            ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
