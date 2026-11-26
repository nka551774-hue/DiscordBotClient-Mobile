import 'package:flutter/material.dart';

class VencordThemeOverrides {
  final Color? railBg;
  final Color? sidebarBg;
  final Color? chatBg;
  final Color? profileBg;
  final Color? bottomBarBg;
  final Color? cardBg;
  final Color? elevatedBg;
  final Color? selectedChannelBg;
  final Color? inputBg;
  final Color? border;
  final Color? textPrimary;
  final Color? textSecondary;
  final Color? textMuted;
  final Color? brand;

  const VencordThemeOverrides({
    this.railBg,
    this.sidebarBg,
    this.chatBg,
    this.profileBg,
    this.bottomBarBg,
    this.cardBg,
    this.elevatedBg,
    this.selectedChannelBg,
    this.inputBg,
    this.border,
    this.textPrimary,
    this.textSecondary,
    this.textMuted,
    this.brand,
  });
}

class DiscordPalette {
  static VencordThemeOverrides? activeThemeOverrides;

  final bool oled;

  const DiscordPalette({required this.oled});

  static const Color blurple = Color(0xFF5865F2);
  static const Color green = Color(0xFF23A55A);
  static const Color yellow = Color(0xFFF0B232);
  static const Color red = Color(0xFFFA777C);
  static const Color danger = Color(0xFFF23F43);
  static const Color greyStatus = Color(0xFF80848E);

  Color get brandColor => activeThemeOverrides?.brand ?? blurple;

  /// 2025/2026 Discord Mobile "Onyx" (oled = true) & "Ash" (oled = false),
  /// dynamically overridden when Vencord Online Themes or QuickCSS are active.
  Color get railBg =>
      activeThemeOverrides?.railBg ??
      (oled ? const Color(0xFF000000) : const Color(0xFF1E1F22));
  Color get sidebarBg =>
      activeThemeOverrides?.sidebarBg ??
      (oled ? const Color(0xFF14151A) : const Color(0xFF2B2D31));
  Color get chatBg =>
      activeThemeOverrides?.chatBg ??
      (oled ? const Color(0xFF101115) : const Color(0xFF313338));
  Color get profileBg =>
      activeThemeOverrides?.profileBg ??
      (oled ? const Color(0xFF0C0D11) : const Color(0xFF18191C));
  Color get bottomBarBg =>
      activeThemeOverrides?.bottomBarBg ??
      (oled ? const Color(0xFF181920) : const Color(0xFF1E1F22));
  Color get cardBg =>
      activeThemeOverrides?.cardBg ??
      (oled ? const Color(0xFF1A1B22) : const Color(0xFF2B2D31));
  Color get elevatedBg =>
      activeThemeOverrides?.elevatedBg ??
      (oled ? const Color(0xFF22232B) : const Color(0xFF1E1F22));
  Color get selectedChannelBg =>
      activeThemeOverrides?.selectedChannelBg ??
      (oled ? const Color(0xFF262831) : const Color(0xFF393C43));
  Color get inputBg =>
      activeThemeOverrides?.inputBg ??
      (oled ? const Color(0xFF22232B) : const Color(0xFF383A40));
  Color get loginInputBg => const Color(0xFF1E1F22);
  Color get border =>
      activeThemeOverrides?.border ??
      (oled ? const Color(0xFF24252E) : const Color(0xFF3F4147));
  Color get textPrimary =>
      activeThemeOverrides?.textPrimary ?? const Color(0xFFF2F3F5);
  Color get textSecondary =>
      activeThemeOverrides?.textSecondary ?? const Color(0xFFB5BAC1);
  Color get textMuted =>
      activeThemeOverrides?.textMuted ?? const Color(0xFF8E929B);
}

ThemeData buildAppTheme({required bool oledBlack}) {
  final p = DiscordPalette(oled: oledBlack);
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: p.railBg,
    canvasColor: p.sidebarBg,
    colorScheme: ColorScheme.dark(
      primary: p.brandColor,
      secondary: p.brandColor,
      surface: p.cardBg,
      error: DiscordPalette.danger,
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
      backgroundColor: const Color(0xFF1C1D24),
      contentTextStyle: TextStyle(color: p.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.profileBg,
      modalBackgroundColor: p.profileBg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
  );
}
