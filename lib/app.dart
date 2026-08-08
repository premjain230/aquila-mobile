import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/main_shell.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/theme_store.dart';
import 'theme/aquila_theme.dart';
import 'widgets/common.dart';

/// Root widget: wires the persisted theme, Firebase bootstrap, and the auth
/// gate. Firebase is initialized here (not in `main`) so that a network or
/// config failure shows a branded screen with a Retry action instead of
/// hanging on the bare native launch surface.
class AquilaApp extends StatefulWidget {
  const AquilaApp({super.key});

  @override
  State<AquilaApp> createState() => _AquilaAppState();
}

enum _BootStatus { initializing, ready, failed }

class _AquilaAppState extends State<AquilaApp> {
  bool _dark = true;
  bool _themeLoaded = false;
  _BootStatus _boot = _BootStatus.initializing;
  String _bootError = '';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _bootstrap();
  }

  Future<void> _loadTheme() async {
    try {
      final dark = await ThemeStore().load();
      if (!mounted) return;
      setState(() {
        _dark = dark;
        _themeLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _themeLoaded = true);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _boot = _BootStatus.initializing;
      _bootError = '';
    });
    try {
      await FirebaseService.instance.initialize();
      if (!mounted) return;
      setState(() => _boot = _BootStatus.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _boot = _BootStatus.failed;
        _bootError = e.toString();
      });
    }
  }

  Widget _home() {
    if (!_themeLoaded || _boot == _BootStatus.initializing) {
      return const SplashScreen();
    }
    if (_boot == _BootStatus.failed) {
      return _BootErrorScreen(error: _bootError, onRetry: _bootstrap);
    }
    return const _AuthGate();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aquila AI',
      debugShowCheckedModeBanner: false,
      theme: AquilaTheme.light(),
      darkTheme: AquilaTheme.dark(),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: _home(),
    );
  }
}

/// Shown when Firebase bootstrap fails so the user can retry instead of
/// being left on a blank surface.
class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AquilaColors.bgBase,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AquilaLogo(size: 64),
              const SizedBox(height: 24),
              const Text(
                'Trouble connecting to Aquila',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AquilaColors.fontMain,
                  fontSize: 17,
                  color: AquilaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AquilaColors.fontMain,
                  fontSize: 14,
                  color: AquilaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AquilaColors.accent,
                  foregroundColor: const Color(0xFF06121A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decides between splash, auth, or the main shell based on auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fa.User?>(
      stream: AuthService.instance.authState,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.active) {
          return const SplashScreen();
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();
        // Enforce the same email-verification gate as the web app.
        if (!user.emailVerified) return VerifyEmailScreen(user: user);
        return MainShell(uid: user.uid);
      },
    );
  }
}