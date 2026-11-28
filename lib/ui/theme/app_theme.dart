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

  /// Official mobile semantic tokens (from the iOS app's design system):
  /// oled = false -> "Dark" (default dark theme), oled = true -> "Onyx".
  /// Vencord Online Themes / QuickCSS can still override each one.
  // BACKGROUND_BASE_LOWEST
  Color get railBg =>
      activeThemeOverrides?.railBg ??
      (oled ? const Color(0xFF000000) : const Color(0xFF121214));
  // BACKGROUND_BASE_LOWER
  Color get sidebarBg =>
      activeThemeOverrides?.sidebarBg ??
      (oled ? const Color(0xFF070709) : const Color(0xFF1A1A1E));
  // BACKGROUND_MOBILE_PRIMARY
  Color get chatBg =>
      activeThemeOverrides?.chatBg ??
      (oled ? const Color(0xFF000000) : const Color(0xFF1C1D23));
  // BACKGROUND_FLOATING (sheets)
  Color get profileBg =>
      activeThemeOverrides?.profileBg ??
      (oled ? const Color(0xFF131318) : const Color(0xFF26272F));
  // BG_BASE_TERTIARY (tab bar)
  Color get bottomBarBg =>
      activeThemeOverrides?.bottomBarBg ??
      (oled ? const Color(0xFF000000) : const Color(0xFF131318));
  // CARD_SECONDARY_BG
  Color get cardBg =>
      activeThemeOverrides?.cardBg ??
      (oled ? const Color(0xFF0C0C10) : const Color(0xFF212229));
  // BG_SURFACE_OVERLAY (rows on sheets)
  Color get elevatedBg =>
      activeThemeOverrides?.elevatedBg ??
      (oled ? const Color(0xFF212229) : const Color(0xFF2C2D35));
  // BACKGROUND_MODIFIER_SELECTED (#4d505b @ 60%)
  Color get selectedChannelBg =>
      activeThemeOverrides?.selectedChannelBg ?? const Color(0x994D505B);
  // REDESIGN_CHAT_INPUT_BACKGROUND
  Color get inputBg =>
      activeThemeOverrides?.inputBg ??
      (oled ? const Color(0x1ABCBCF0) : const Color(0x1F6C6F7C));
  Color get loginInputBg => const Color(0xFF1E1F22);
  // BORDER_SUBTLE
  Color get border =>
      activeThemeOverrides?.border ??
      (oled ? const Color(0x246C6F7C) : const Color(0x1F6C6F7C));
  // HEADER_PRIMARY
  Color get textPrimary =>
      activeThemeOverrides?.textPrimary ??
      (oled ? const Color(0xFFECEDEF) : const Color(0xFFE4E5E8));
  // TEXT_SECONDARY
  Color get textSecondary =>
      activeThemeOverrides?.textSecondary ??
      (oled ? const Color(0xFFA8AAB4) : const Color(0xFF9597A3));
  // TEXT_MUTED
  Color get textMuted =>
      activeThemeOverrides?.textMuted ?? const Color(0xFF818491);
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
      backgroundColor: p.elevatedBg,
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
