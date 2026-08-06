import 'package:flutter/material.dart';

/// Design token system translated 1:1 from the Aquila AI web app CSS
/// (`--bg-base`, `--bg-card`, `--accent`, ... dark default + `.light-mode`).
///
/// Fonts: Sora (UI) and Space Mono (mono/labels/numbers) — both bundled locally.
class AquilaColors {
  AquilaColors._();

  // Dark theme (default)
  static const Color bgBase = Color(0xFF0A0B0F);
  static const Color bgSidebar = Color(0xFF0F1117);
  static const Color bgCard = Color(0xFF1A1D27);
  static const Color bgInput = Color(0xFF1E2130);
  static const Color accent = Color(0xFF00D4FF);
  static const Color accentBright = Color(0xFF33DDFF);
  static const Color accent2 = Color(0xFFA78BFA);
  static const Color accent3 = Color(0xFFFF6B6B);
  static const Color accent4 = Color(0xFFF59E0B);
  static const Color green = Color(0xFF34D399);
  static const Color amber = Color(0xFFFBBF24);
  static const Color textPrimary = Color(0xFFF0F0F8);
  static const Color textSecondary = Color(0xFF8B8FA8);
  static const Color textMuted = Color(0xFF4A4D62);
  static const Color borderColor = Color(0x12FFFFFF);
  static const Color borderStrong = Color(0x29FFFFFF);
  static const Color buttonGradientStart = Color(0xFF00B4D8);
  static const Color buttonGradientEnd = Color(0xFF48E3FF);
  static const Color onAccentText = Color(0xFF040D12);
  static const Color avatarText = Color(0xFF06121A);
  static const Color errorPink = Color(0xFFF472B6);
  static const Color successTeal = Color(0xFF06D6CF);

  // Light theme
  static const Color lightBgBase = Color(0xFFF4F5F9);
  static const Color lightBgSidebar = Color(0xFFECEDF2);
  static const Color lightBgCard = Color(0xFFFFFFFF);
  static const Color lightBgInput = Color(0xFFF0F1F5);
  static const Color lightTextPrimary = Color(0xFF16162A);
  static const Color lightTextSecondary = Color(0xFF5A5D72);
  static const Color lightTextMuted = Color(0xFF9EA0B4);
  static const Color lightBorderColor = Color(0x14000000);

  // Fonts
  static const String fontMain = 'Sora';
  static const String fontMono = 'SpaceMono';

  /// Subject color palette used across planner + analyze (web `subjectColor()`).
  static const List<Color> subjectPalette = [
    Color(0xFF00D4FF),
    Color(0xFFA78BFA),
    Color(0xFFF59E0B),
    Color(0xFFFF6B6B),
    Color(0xFF34D399),
    Color(0xFF60A5FA),
    Color(0xFFF472B6),
    Color(0xFFFB923C),
  ];

  static Color subjectColor(int index) =>
      subjectPalette[(index.abs()) % subjectPalette.length];
}

/// Curated, production-ready theme data for both modes.
class AquilaTheme {
  AquilaTheme._();

  static ThemeData dark() => _build(Brightness.dark, mode: _ThemeMode.dark);
  static ThemeData light() => _build(Brightness.light, mode: _ThemeMode.light);

  static ThemeData _build(Brightness brightness, {required _ThemeMode mode}) {
    final bool dark = mode == _ThemeMode.dark;

    final Color bgBase = dark ? AquilaColors.bgBase : AquilaColors.lightBgBase;
    final Color bgCard = dark ? AquilaColors.bgCard : AquilaColors.lightBgCard;
    final Color bgInput = dark ? AquilaColors.bgInput : AquilaColors.lightBgInput;
    final Color textPrimary =
        dark ? AquilaColors.textPrimary : AquilaColors.lightTextPrimary;
    final Color textSecondary =
        dark ? AquilaColors.textSecondary : AquilaColors.lightTextSecondary;
    final Color textMuted =
        dark ? AquilaColors.textMuted : AquilaColors.lightTextMuted;
    final Color border =
        dark ? AquilaColors.borderColor : AquilaColors.lightBorderColor;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AquilaColors.accent,
      brightness: brightness,
      primary: AquilaColors.accent,
      secondary: AquilaColors.accent2,
      error: AquilaColors.accent3,
      surface: bgCard,
    );

    final baseTextTheme = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(fontFamily: AquilaColors.fontMain);

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontFamily: AquilaColors.fontMain,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontFamily: AquilaColors.fontMain,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.03,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: AquilaColors.fontMain,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: AquilaColors.fontMain,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontFamily: AquilaColors.fontMain,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontFamily: AquilaColors.fontMain,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontFamily: AquilaColors.fontMain,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontFamily: AquilaColors.fontMain,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontFamily: AquilaColors.fontMain,
        color: textSecondary,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontFamily: AquilaColors.fontMain,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontFamily: AquilaColors.fontMain,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontFamily: AquilaColors.fontMono,
        letterSpacing: 0.1,
      ),
    );

    // Web mono labels: uppercase mono, letter-spacing, muted.
    TextStyle monoMicro(double size, {Color? color}) => TextStyle(
          fontFamily: AquilaColors.fontMono,
          fontSize: size,
          letterSpacing: 0.12,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: color ?? textSecondary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgBase,
      canvasColor: bgBase,
      dividerColor: border,
      fontFamily: AquilaColors.fontMain,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      extensions: [
        AquilaThemeExt(
          bgBase: bgBase,
          bgSidebar: dark ? AquilaColors.bgSidebar : AquilaColors.lightBgSidebar,
          bgCard: bgCard,
          bgInput: bgInput,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textMuted: textMuted,
          border: border,
          darkMode: dark,
          monoMicro: monoMicro,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: bgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textSecondary),
        titleTextStyle: TextStyle(
          fontFamily: AquilaColors.fontMain,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        hintStyle: const TextStyle(
          fontFamily: AquilaColors.fontMain,
          fontSize: 14,
          color: AquilaColors.textMuted,
        ),
        labelStyle: TextStyle(
          fontFamily: AquilaColors.fontMain,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AquilaColors.textSecondary,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: AquilaColors.fontMono,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08,
          color: AquilaColors.accent,
        ),
        errorStyle: const TextStyle(
          fontFamily: AquilaColors.fontMono,
          fontSize: 11,
          color: AquilaColors.accent3,
          height: 1.1,
        ),
        helperStyle: TextStyle(
          fontFamily: AquilaColors.fontMono,
          fontSize: 11,
          color: AquilaColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0x8000D4FF), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x99FF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x99FF6B6B), width: 1.2),
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontFamily: AquilaColors.fontMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AquilaColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AquilaColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(
          fontFamily: AquilaColors.fontMain,
          fontSize: 13,
          color: AquilaColors.textPrimary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AquilaColors.accent
              : Colors.white.withValues(alpha: dark ? 0.5 : 0.4),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0x3300D4FF)
              : dark
                  ? const Color(0x33FFFFFF)
                  : const Color(0x33000000),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AquilaColors.accent,
        foregroundColor: AquilaColors.onAccentText,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AquilaColors.bgCard,
        contentTextStyle: const TextStyle(
          fontFamily: AquilaColors.fontMain,
          fontSize: 13,
          color: AquilaColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
    );
  }
}

enum _ThemeMode { dark, light }

/// App-specific theme tokens accessible via `Theme.of(context).extension`.
class AquilaThemeExt extends ThemeExtension<AquilaThemeExt> {
  final Color bgBase;
  final Color bgSidebar;
  final Color bgCard;
  final Color bgInput;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final bool darkMode;
  final TextStyle Function(double size, {Color? color}) monoMicro;

  const AquilaThemeExt({
    required this.bgBase,
    required this.bgSidebar,
    required this.bgCard,
    required this.bgInput,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.darkMode,
    required this.monoMicro,
  });

  static AquilaThemeExt of(BuildContext context) =>
      Theme.of(context).extension<AquilaThemeExt>()!;

  @override
  AquilaThemeExt copyWith({bool? darkMode}) => AquilaThemeExt(
        bgBase: bgBase,
        bgSidebar: bgSidebar,
        bgCard: bgCard,
        bgInput: bgInput,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textMuted: textMuted,
        border: border,
        darkMode: darkMode ?? this.darkMode,
        monoMicro: monoMicro,
      );

  @override
  AquilaThemeExt lerp(ThemeExtension<AquilaThemeExt>? other, double t) => this;
}