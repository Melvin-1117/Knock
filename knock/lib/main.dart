import 'dart:async';
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

const _defaultQuickMessages = [
  '\u{1F44B} Hey!',
  '\u{1F355} Wanna grab food?',
  "\u{1F3AE} Let's play!",
  '\u{1F4DE} Call me',
  '\u{1F602} LOL',
  '\u{2764}\u{FE0F} Miss you',
  '\u{2615} Coffee break?',
  '\u{1F3E0} Coming home?',
  '\u{1F4AA} You got this!',
  '\u{1FAC2} Sending hugs',
];

const _accentColors = [
  Color(0xFF1E88E5),
  Color(0xFF00BFA6),
  Color(0xFFFF6D00),
  Color(0xFFE040FB),
  Color(0xFF00ACC1),
  Color(0xFFFF4081),
];

const _primaryColor = Color(0xFF1E88E5);

const _avatarEmojis = [
  '\u{1F600}',
  '\u{1F60E}',
  '\u{1F917}',
  '\u{1F973}',
  '\u{1F60A}',
  '\u{1F920}',
  '\u{1F98A}',
  '\u{1F431}',
  '\u{1F436}',
  '\u{1F981}',
  '\u{1F43B}',
  '\u{1F43C}',
  '\u{1F31F}',
  '\u{26A1}',
  '\u{1F525}',
  '\u{1F308}',
  '\u{1F3AF}',
  '\u{1F48E}',
  '\u{1F3AE}',
  '\u{1F3B5}',
  '\u{1F4DA}',
  '\u{26BD}',
  '\u{1F3C0}',
  '\u{1F3A8}',
];

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
        brightness: Brightness.light,
        colorSchemeSeed: _primaryColor,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF333333)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontSize: 22,
          ),
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
      child: CustomPaint(painter: _KnockLogoPainter()),
    );
  }
}

class _KnockLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Simple black heart shape
    final path = Path();
    path.moveTo(w * 0.5, h * 0.9);
    path.cubicTo(w * 0.1, h * 0.55, w * 0.1, h * 0.15, w * 0.5, h * 0.35);
    path.cubicTo(w * 0.9, h * 0.15, w * 0.9, h * 0.55, w * 0.5, h * 0.9);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      backgroundColor: Colors.white,
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
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap into your circle',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500],
                    letterSpacing: 1,
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
        if (_selectedAvatar != null)
          insertData['avatar_emoji'] = _selectedAvatar;
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
      backgroundColor: Colors.white,
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
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick a username to get started',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 36),
        TextField(
          controller: _usernameC,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F7),
            prefixIcon: Icon(Icons.person_outline, color: Colors.grey[500]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
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
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
          backgroundColor: _primaryColor.withValues(alpha: 0.1),
          child: Text(
            _selectedAvatar ?? displayInitial,
            style: TextStyle(
              fontSize: _selectedAvatar != null ? 44 : 38,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hi, ${_usernameC.text.trim()}!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose your profile picture',
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
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
                            ? _primaryColor.withValues(alpha: 0.12)
                            : const Color(0xFFF5F5F7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? _primaryColor
                              : Colors.grey.withValues(alpha: 0.25),
                          width: selected ? 2.5 : 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: _primaryColor.withValues(alpha: 0.2),
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
                          color: isCustom ? _primaryColor : null,
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
                        color: selected ? _primaryColor : Colors.grey[600],
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
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
          child: Text(
            'Skip for now',
            style: TextStyle(
              color: Colors.grey[500],
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
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 44,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "You're all set!",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Here's your personal Knock ID.\nShare it with friends to connect!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'YOUR KNOCK ID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: Colors.grey[500],
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
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
  String? _myKnockId;
  String? _myDisplayName;
  String? _myAvatarEmoji;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFriends();
    _listenForKnocks();
  }

  @override
  void dispose() {
    _knockSub?.cancel();
    super.dispose();
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

      setState(() {
        _friends = List<Map<String, dynamic>>.from(rows);
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
                    backgroundColor: _primaryColor,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add Friend',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter your friend's Knock ID to connect",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                ),
                decoration: InputDecoration(
                  hintText: 'KNCK-XXXX',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.normal,
                    letterSpacing: 2,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  prefixIcon: const Icon(Icons.tag, color: _primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim().toUpperCase()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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

      await _sb.from('connections').insert({
        'user_id': _uid,
        'friend_id': profile['id'],
        'label': 'Friend',
      });

      _loadFriends();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile['display_name'] ?? 'Friend'} added!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text(
          'KNOCK',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontSize: 20,
            color: _primaryColor,
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
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (_myKnockId != null)
                        Text(
                          _myKnockId!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _primaryColor.withValues(alpha: 0.12),
                    child: Text(
                      _myAvatarEmoji ?? displayInitial,
                      style: TextStyle(
                        fontSize: _myAvatarEmoji != null ? 20 : 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
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
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: _addFriend,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Friend',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
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

                  return _FriendCard(
                    name: name,
                    label: label,
                    friendId: friendId,
                    accentColor: color,
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
              color: _primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No friends yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Friend" and enter their\nKnock ID to connect',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 28),
          if (_myKnockId != null) ...[
            Text(
              'YOUR KNOCK ID',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: Colors.grey[500],
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
                  color: _primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _primaryColor.withValues(alpha: 0.2),
                  ),
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
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: _primaryColor.withValues(alpha: 0.6),
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
            backgroundColor: Colors.green,
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    final displayInitial = _nameC.text.isNotEmpty
        ? _nameC.text[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
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
                        color: _primaryColor,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
                    backgroundColor: _primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      _avatarEmoji ?? displayInitial,
                      style: TextStyle(
                        fontSize: _avatarEmoji != null ? 44 : 38,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
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
                        color: _primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
            Text(
              'Tap an avatar below to change',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),

            // ---- Display name ----
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DISPLAY NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameC,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.person_outline, color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ---- Knock ID ----
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'YOUR KNOCK ID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag, color: _primaryColor, size: 20),
                  const SizedBox(width: 10),
                  SelectableText(
                    _knockId ?? '------',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: _primaryColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    color: _primaryColor,
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
              child: Text(
                'PROFILE PICTURE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Colors.grey[500],
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
                                    ? _primaryColor.withValues(alpha: 0.12)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? _primaryColor
                                      : Colors.grey.withValues(alpha: 0.25),
                                  width: selected ? 2.5 : 1.5,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: _primaryColor.withValues(
                                            alpha: 0.2,
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
                                  color: isCustom ? _primaryColor : null,
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
                                    ? _primaryColor
                                    : Colors.grey[600],
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
  });

  final String name;
  final String label;
  final String friendId;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: accentColor.withValues(alpha: 0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
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
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
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
  String? _sentMessage;

  Future<void> _sendMessage(String message) async {
    HapticFeedback.heavyImpact();
    setState(() => _sentMessage = message);

    try {
      await _sb.from('knocks').insert({
        'sender_id': _uid,
        'receiver_id': widget.friendId,
        'message': message,
      });
      debugPrint('Knock sent to ${widget.name}: $message');
    } catch (e) {
      debugPrint('Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _sentMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: widget.accentColor.withValues(alpha: 0.12),
              child: Text(
                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: widget.accentColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SEND A KNOCK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: _defaultQuickMessages.map((msg) {
                  final isSent = _sentMessage == msg;
                  return _QuickMessageButton(
                    message: msg,
                    accentColor: widget.accentColor,
                    isSent: isSent,
                    onTap: () => _sendMessage(msg),
                  );
                }).toList(),
              ),
            ),
            AnimatedOpacity(
              opacity: _sentMessage != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: widget.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Knock sent!',
                      style: TextStyle(
                        color: widget.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-message button widget
// ---------------------------------------------------------------------------

class _QuickMessageButton extends StatelessWidget {
  const _QuickMessageButton({
    required this.message,
    required this.accentColor,
    required this.isSent,
    required this.onTap,
  });

  final String message;
  final Color accentColor;
  final bool isSent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSent ? accentColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSent ? accentColor : Colors.grey.withValues(alpha: 0.2),
            width: isSent ? 1.5 : 1,
          ),
          boxShadow: isSent
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSent ? accentColor : const Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}
