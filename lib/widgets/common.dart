import 'package:flutter/material.dart';

import '../theme/aquila_theme.dart';

/// Reusable branded primitives shared by the auth screens & shell.

/// Gradient CTA button (mirrors web `.btn-gradient`).
class AquilaGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final Widget? icon;
  final bool fullWidth;

  const AquilaGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.height = 52,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? [AquilaColors.buttonGradientStart, AquilaColors.buttonGradientEnd]
                : [AquilaColors.textMuted, AquilaColors.bgInput],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Container(
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AquilaColors.onAccentText,
                      ),
                    )
                  : Row(
                      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          icon!,
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: AquilaColors.fontMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AquilaColors.onAccentText,
                          ),
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

/// Secondary (outlined) button.
class AquilaOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;

  const AquilaOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: ext.border.withValues(alpha: 1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: ext.textPrimary,
          backgroundColor: ext.bgCard,
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: ext.textSecondary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

/// Small repeating logo orb + wordmark.
class AquilaLogo extends StatelessWidget {
  final double size;
  const AquilaLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AquilaColors.accent, AquilaColors.accent2],
            ),
            boxShadow: [
              BoxShadow(
                color: AquilaColors.accent.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(Icons.auto_awesome, color: AquilaColors.avatarText, size: size * 0.45),
        ),
      ],
    );
  }
}

/// Label above inputs styled like the web mono micro labels.
class MonoLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const MonoLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Text(
      text.toUpperCase(),
      style: ext.monoMicro(11, color: color ?? ext.textSecondary),
    );
  }
}

/// Shows a snackbar (single API for errors/confirmation).
void showAquilaSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: error ? AquilaColors.accent3 : AquilaColors.green,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}