import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';
import 'verify_email_screen.dart';

/// Mirrors the web two-step signup: Step 1 name, Step 2 email + password.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  int _step = 1;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_step == 1) {
      setState(() => _step = 2);
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthService.instance.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      final user = AuthService.instance.currentUser;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user!)),
      );
    } on fa.FirebaseAuthException catch (e) {
      showAquilaSnack(context, _friendly(e), error: true);
      setState(() => _submitting = false);
    } catch (e) {
      showAquilaSnack(context, 'Could not create your account. Please try again.', error: true);
      setState(() => _submitting = false);
    }
  }

  String _friendly(fa.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Sign up failed.';
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
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              _step == 1 ? Navigator.of(context).pop() : setState(() => _step = 1),
                          icon: Icon(Icons.arrow_back, color: ext.textSecondary),
                        ),
                        const Spacer(),
                        Text('STEP $_step / 2', style: ext.monoMicro(10, color: ext.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Center(child: AquilaLogo(size: 56)),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text(
                        'Create your account',
                        style: TextStyle(
                          fontFamily: AquilaColors.fontMain,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AquilaColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (_step == 1) ...[
                      const MonoLabel('What should we call you?'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: 'Your name'),
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ] else ...[
                      const MonoLabel('Email'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(hintText: 'you@example.com'),
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 18),
                      const MonoLabel('Password'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: 'At least 6 characters',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: ext.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Minimum 6 characters'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    const SizedBox(height: 28),
                    AquilaGradientButton(
                      label: _step == 1 ? 'Continue' : 'Create Account',
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Already have an account? Sign in',
                          style: TextStyle(
                            fontFamily: AquilaColors.fontMain,
                            fontSize: 13,
                            color: AquilaColors.accent,
                          ),
                        ),
                      ),
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