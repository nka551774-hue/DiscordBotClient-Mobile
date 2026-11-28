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

  /// Non-Onyx variant: false = Ash (Discord gray, default), true = Dark.
  static bool darker = false;
  static Color _t(bool oled, int ash, int dark, int onyx) =>
      Color(oled ? onyx : (darker ? dark : ash));

  static const Color blurple = Color(0xFF5865F2);
  static const Color green = Color(0xFF23A55A);
  static const Color yellow = Color(0xFFF0B232);
  static const Color red = Color(0xFFFA777C);
  static const Color danger = Color(0xFFF23F43);
  static const Color greyStatus = Color(0xFF80848E);

  Color get brandColor => activeThemeOverrides?.brand ?? blurple;

  /// Official mobile semantic tokens (from the iOS app's design system):
  /// Ash (DARK tokens, default gray) / Dark (DARKER) / Onyx (MIDNIGHT).
  /// Vencord Online Themes / QuickCSS can still override each one.
  // BACKGROUND_BASE_LOWEST
  Color get railBg =>
      activeThemeOverrides?.railBg ??
      _t(oled, 0xFF2C2D32, 0xFF121214, 0xFF000000);
  // BACKGROUND_BASE_LOWER
  Color get sidebarBg =>
      activeThemeOverrides?.sidebarBg ??
      _t(oled, 0xFF323339, 0xFF1A1A1E, 0xFF070709);
  // BACKGROUND_MOBILE_PRIMARY
  Color get chatBg =>
      activeThemeOverrides?.chatBg ??
      _t(oled, 0xFF313338, 0xFF1C1D23, 0xFF000000);
  // BG_BASE_SECONDARY (ACTION_SHEET_BACKGROUND_COLOR)
  Color get profileBg =>
      activeThemeOverrides?.profileBg ??
      _t(oled, 0xFF2B2D31, 0xFF1C1D23, 0xFF000000);
  // BG_BASE_TERTIARY (tab bar)
  Color get bottomBarBg =>
      activeThemeOverrides?.bottomBarBg ??
      _t(oled, 0xFF232428, 0xFF131318, 0xFF000000);
  // CARD_SECONDARY_BG
  Color get cardBg =>
      activeThemeOverrides?.cardBg ??
      _t(oled, 0xFF2B2D31, 0xFF212229, 0xFF0C0C10);
  // CARD_PRIMARY_BG (cards / grouped rows on sheets)
  Color get elevatedBg =>
      activeThemeOverrides?.elevatedBg ??
      _t(oled, 0xFF313338, 0xFF26272F, 0xFF131318);
  // BACKGROUND_MODIFIER_SELECTED (#4d505b @ 60%)
  Color get selectedChannelBg =>
      activeThemeOverrides?.selectedChannelBg ??
      _t(oled, 0x994E5058, 0x994D505B, 0x994D505B);
  // REDESIGN_CHAT_INPUT_BACKGROUND
  Color get inputBg =>
      activeThemeOverrides?.inputBg ??
      _t(oled, 0xFF1E1F22, 0x1F6C6F7C, 0x1ABCBCF0);
  Color get loginInputBg => const Color(0xFF1E1F22);
  // BG_MOD_STRONG (voice panel buttons / pills)
  Color get modStrong => _t(oled, 0x8A4E5058, 0x3D6C6F7C, 0x2E6C6F7C);
  // INTERACTIVE_NORMAL
  Color get interactiveNormal => _t(oled, 0xFFB5BAC1, 0xFFC7C8CE, 0xFFC7C8CE);
  // BACKGROUND_MENTIONED (gutter is YELLOW_300 #f0b232)
  Color get mentionedBg => _t(oled, 0x1AF0B232, 0x14FCC145, 0x14FCC145);
  // BORDER_SUBTLE
  Color get border =>
      activeThemeOverrides?.border ??
      _t(oled, 0x14FFFFFF, 0x1F6C6F7C, 0x246C6F7C);
  // HEADER_PRIMARY
  Color get textPrimary =>
      activeThemeOverrides?.textPrimary ??
      _t(oled, 0xFFF2F3F5, 0xFFE4E5E8, 0xFFECEDEF);
  // TEXT_SECONDARY
  Color get textSecondary =>
      activeThemeOverrides?.textSecondary ??
      _t(oled, 0xFFB5BAC1, 0xFF9597A3, 0xFFA8AAB4);
  // TEXT_MUTED
  Color get textMuted =>
      activeThemeOverrides?.textMuted ??
      _t(oled, 0xFF949BA4, 0xFF818491, 0xFF818491);
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
