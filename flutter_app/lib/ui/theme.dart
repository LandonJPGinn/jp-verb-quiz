import 'package:flutter/material.dart';

/// Design tokens for the Katsuyou look — inspired by Anki's calm surfaces,
/// Duolingo's bold rounded actions, and Kanji Study's clean info layout.
abstract final class AppColors {
  // Primary — ai-iro indigo
  static const indigo = Color(0xFF2D5DA1);
  static const indigoDark = Color(0xFF1E3F73);
  static const indigoSoft = Color(0xFFE8F0FC);
  static const indigoSoftDark = Color(0xFF2A3A55);

  // Accents
  static const flame = Color(0xFFF76B15); // streak
  static const success = Color(0xFF3FA845);
  static const successSoft = Color(0xFFE4F6E5);
  static const successSoftDark = Color(0xFF1E3A26);
  static const error = Color(0xFFE13D3D);
  static const errorSoft = Color(0xFFFCE9E9);
  static const errorSoftDark = Color(0xFF442525);
  static const gold = Color(0xFFFFC433);
  static const chip = Color(0xFFFFB055);

  // Surfaces
  static const canvasLight = Color(0xFFF6F7FB);
  static const cardLight = Colors.white;
  static const canvasDark = Color(0xFF16181F);
  static const cardDark = Color(0xFF22252F);
  static const outline = Color(0xFFDDE1EA);
  static const outlineDark = Color(0xFF3A3F4E);

  static Color canvas(Brightness b) =>
      b == Brightness.light ? canvasLight : canvasDark;
  static Color card(Brightness b) =>
      b == Brightness.light ? cardLight : cardDark;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    primary: AppColors.indigo,
    surface: AppColors.cardLight,
    onSurface: AppColors.indigoDark,
  );

  return _base(scheme, Brightness.light);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    brightness: Brightness.dark,
    primary: const Color(0xFF8FB4EA), // lighter indigo for dark surfaces
    surface: AppColors.cardDark,
    onSurface: Colors.white,
  );

  return _base(scheme, Brightness.dark);
}

ThemeData _base(ColorScheme scheme, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final onSurface = scheme.onSurface;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? AppColors.canvasDark
        : AppColors.canvasLight,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.canvasDark : AppColors.canvasLight,
      foregroundColor: dark ? Colors.white : AppColors.indigoDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: dark ? Colors.white : AppColors.indigoDark,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(
        color: dark ? Colors.white : AppColors.indigoDark,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: dark ? AppColors.indigoDark : Colors.white,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        side: BorderSide(color: scheme.primary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    cardTheme: CardThemeData(
      color: dark ? AppColors.cardDark : AppColors.cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark ? AppColors.outlineDark : AppColors.outline,
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? AppColors.cardDark : AppColors.cardLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: TextStyle(color: onSurface, fontSize: 14.5),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? AppColors.cardDark : AppColors.cardLight,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.primary,
      textColor: onSurface,
      subtitleTextStyle: TextStyle(
        color: onSurface.withValues(alpha: 0.75),
        fontSize: 12.5,
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : (dark ? AppColors.outlineDark : AppColors.outline),
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(
          BorderSide(color: dark ? AppColors.outlineDark : AppColors.outline),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? AppColors.indigoDark : Colors.white)
              : onSurface,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.cardDark : Colors.white,
      hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.75)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: dark ? AppColors.outlineDark : AppColors.outline,
          width: 2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2.5),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.cardDark : Colors.white,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Secondary text colour with a dark-mode-safe opacity: plain low alphas of
/// white wash out on the dark cards, so dark mode gets a higher floor.
Color muted(BuildContext context, [double lightAlpha = 0.6]) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.white.withValues(alpha: 0.85)
    : AppColors.indigoDark.withValues(alpha: lightAlpha);

/// Accent colour for icons that must read on both themes.
Color accentOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF8FB4EA)
    : AppColors.indigo;
