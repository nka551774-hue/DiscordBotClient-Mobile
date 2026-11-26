import 'package:flutter/material.dart';

class DiscordPalette {
  final bool oled;

  const DiscordPalette({required this.oled});

  static const Color blurple = Color(0xFF5865F2);
  static const Color green = Color(0xFF23A55A);
  static const Color yellow = Color(0xFFF0B232);
  static const Color red = Color(0xFFF23F43);
  static const Color greyStatus = Color(0xFF80848E);

  /// Pure #000000 turns off physical OLED subpixels on modern Android & iPhone screens.
  Color get chatBg => oled ? const Color(0xFF000000) : const Color(0xFF313338);
  Color get railBg => oled ? const Color(0xFF000000) : const Color(0xFF1E1F22);
  Color get sidebarBg =>
      oled ? const Color(0xFF07080A) : const Color(0xFF2B2D31);
  Color get cardBg => oled ? const Color(0xFF0E1014) : const Color(0xFF2B2D31);
  Color get inputBg => oled ? const Color(0xFF12141A) : const Color(0xFF383A40);
  Color get border => oled ? const Color(0xFF1C1F26) : const Color(0xFF3F4147);
  Color get textPrimary => const Color(0xFFF2F3F5);
  Color get textSecondary => const Color(0xFFB5BAC1);
  Color get textMuted => const Color(0xFF80848E);

  static DiscordPalette of(BuildContext context, {required bool oled}) =>
      DiscordPalette(oled: oled);
}

ThemeData buildAppTheme({required bool oledBlack}) {
  final p = DiscordPalette(oled: oledBlack);
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: p.chatBg,
    canvasColor: p.sidebarBg,
    colorScheme: ColorScheme.dark(
      primary: DiscordPalette.blurple,
      secondary: DiscordPalette.blurple,
      surface: p.cardBg,
      error: DiscordPalette.red,
      onPrimary: Colors.white,
      onSurface: p.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.chatBg,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: p.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerColor: p.border,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.cardBg,
      contentTextStyle: TextStyle(color: p.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.sidebarBg,
      modalBackgroundColor: p.sidebarBg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
  );
}
