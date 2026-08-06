import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/main_shell.dart';
import 'services/auth_service.dart';
import 'services/theme_store.dart';
import 'theme/aquila_theme.dart';

/// Root widget: wires the persisted theme and the auth gate.
class AquilaApp extends StatefulWidget {
  const AquilaApp({super.key});

  @override
  State<AquilaApp> createState() => _AquilaAppState();
}

class _AquilaAppState extends State<AquilaApp> {
  bool _dark = true;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final dark = await ThemeStore().load();
    if (!mounted) return;
    setState(() {
      _dark = dark;
      _themeLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aquila AI',
      debugShowCheckedModeBanner: false,
      theme: AquilaTheme.dark(),
      darkTheme: AquilaTheme.dark(),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: _themeLoaded ? const _AuthGate() : const _LoadingShell(),
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

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AquilaColors.bgBase,
      body: Center(
        child: CircularProgressIndicator(color: AquilaColors.accent),
      ),
    );
  }
}