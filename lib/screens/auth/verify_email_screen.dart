import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';
import '../shell/main_shell.dart';

/// Mirrors the web verify-email page: waits for the user to confirm the link,
/// with resend + refresh actions.
class VerifyEmailScreen extends StatefulWidget {
  final fa.User user;
  const VerifyEmailScreen({super.key, required this.user});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  bool _resending = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    // Refresh auth state periodically so the app proceeds automatically once
    // the user verifies (mirrors web interval-based check).
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      await widget.user.reload();
      if (widget.user.emailVerified && mounted) {
        _timer?.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MainShell(uid: widget.user.uid),
          ),
          (route) => false,
        );
      }
    } catch (_) {
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await widget.user.sendEmailVerification();
      if (mounted) showAquilaSnack(context, 'Verification email sent.');
    } catch (_) {
      if (mounted) {
        showAquilaSnack(context, 'Could not resend. Try again shortly.', error: true);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
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
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AquilaColors.accent.withValues(alpha: 0.12),
                      border: Border.all(color: AquilaColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AquilaColors.accent,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verify your email',
                    style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a verification link to\n${widget.user.email ?? ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 14,
                      height: 1.5,
                      color: ext.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 34),
                  AquilaGradientButton(
                    label: 'I\'ve verified — continue',
                    loading: _checking,
                    onPressed: _check,
                  ),
                  const SizedBox(height: 12),
                  AquilaOutlineButton(
                    label: 'Resend email',
                    loading: _resending,
                    onPressed: _resend,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ext.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Waiting for verification…',
                        style: ext.monoMicro(11, color: ext.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}