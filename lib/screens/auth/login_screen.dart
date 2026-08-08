import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await AuthService.instance.login(_email.text, _password.text);
      // Route to the shell/verify via the auth gate's stream.
    } on fa.FirebaseAuthException catch (e) {
      if (mounted) showAquilaSnack(context, _friendly(e), error: true);
    } catch (e) {
      if (mounted) {
        showAquilaSnack(context, 'Sign in failed. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _google() async {
    setState(() => _submitting = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } on fa.FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user') {
        // user cancelled — no-op
      } else {
        if (mounted) showAquilaSnack(context, _friendly(e), error: true);
      }
    } catch (e) {
      if (mounted) showAquilaSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      showAquilaSnack(context, 'Enter your email first to reset your password.', error: true);
      return;
    }
try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) showAquilaSnack(context, 'Password reset link sent to $email');
    } catch (e) {
      if (mounted) {
        showAquilaSnack(context, 'Could not send reset email.', error: true);
      }
    }
  }

  String _friendly(fa.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return e.message ?? 'Sign in failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      backgroundColor: ext.bgBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: AquilaLogo(size: 64)),
                    const SizedBox(height: 22),
Center(
                      child: Text(
                        'Welcome back',
                        style: TextStyle(
                          fontFamily: AquilaColors.fontMain,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: ext.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Sign in to continue your learning journey',
                        style: TextStyle(
                          fontFamily: AquilaColors.fontMain,
                          fontSize: 14,
                          color: ext.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const MonoLabel('Email'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(hintText: 'you@example.com'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    const MonoLabel('Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Your password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: ext.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      onFieldSubmitted: (_) => _signIn(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgot,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontFamily: AquilaColors.fontMain,
                            fontSize: 13,
                            color: AquilaColors.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AquilaGradientButton(
                      label: 'Sign In',
                      loading: _submitting,
                      onPressed: _signIn,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: Divider(color: ext.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: ext.monoMicro(10, color: ext.textMuted)),
                        ),
                        Expanded(child: Divider(color: ext.border)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AquilaOutlineButton(
                      label: 'Continue with Google',
                      icon: Icon(Icons.g_mobiledata, color: ext.textPrimary),
                      loading: _submitting,
                      onPressed: _google,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New to Aquila?',
                          style: TextStyle(color: ext.textSecondary, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          ),
                          child: const Text(
                            'Create account',
                            style: TextStyle(
                              color: AquilaColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}