import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../../services/vencord_engine.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'user_profile_sheet.dart';

// ============================================================================
// 1. Vencord Settings Screen (Plugins / Themes & QuickCSS / Backup & Restore)
// ============================================================================
class VencordSettingsScreen extends StatefulWidget {
  final BotClientController controller;
  final int initialTabIndex;

  const VencordSettingsScreen({
    super.key,
    required this.controller,
    this.initialTabIndex = 0,
  });

  @override
  State<VencordSettingsScreen> createState() => _VencordSettingsScreenState();
}

class _VencordSettingsScreenState extends State<VencordSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _searchQuery = '';
  int _pluginFilter = 0; // 0 = All, 1 = Enabled, 2 = Disabled, 3 = Custom

  late final TextEditingController _themeLinksCtrl;
  late final TextEditingController _quickCssCtrl;
  late bool _useQuickCss;
  bool _applyingThemes = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    final vc = widget.controller.vencord;
    _useQuickCss = vc.useQuickCss;
    _themeLinksCtrl = TextEditingController(text: vc.themeLinks.join('\n'));
    _quickCssCtrl = TextEditingController(text: vc.quickCss);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _themeLinksCtrl.dispose();
    _quickCssCtrl.dispose();
    super.dispose();
  }

  void _openInstallCustomPluginModal(DiscordPalette p) {
    final urlCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    bool loading = false;
    String? errText;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '安裝自訂 Vencord 插件 (Userplugin)',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '支援貼上 GitHub Vencord 插件網址 (.ts / .tsx / .js / 資料夾連結) 或直接貼上 definePlugin({...}) 原始碼與 JSON 描述檔。',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    style: TextStyle(color: p.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'GitHub / Raw 插件網址 (選填)',
                      hintText:
                          'https://github.com/Vendicated/Vencord/tree/main/src/plugins/...',
                      filled: true,
                      fillColor: p.elevatedBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    maxLines: 6,
                    style: const TextStyle(
                      color: Color(0xFFE3E5E8),
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      labelText: '或直接貼上 definePlugin({...}) 程式碼 / JSON',
                      hintText:
                          'export default definePlugin({ name: "MyPlugin", description: "...", ... })',
                      filled: true,
                      fillColor: p.elevatedBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (errText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errText!,
                      style: const TextStyle(
                        color: DiscordPalette.red,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: p.brandColor,
                        ),
                        onPressed: loading
                            ? null
                            : () async {
                                setM(() {
                                  loading = true;
                                  errText = null;
                                });
                                try {
                                  final url = urlCtrl.text.trim();
                                  final code = codeCtrl.text.trim();
                                  final VencordPluginDef installed;
                                  if (url.isNotEmpty) {
                                    installed = await widget.controller.vencord
                                        .importCustomPluginFromUrl(
                                      url,
                                      widget.controller.prefs,
                                    );
                                  } else {
                                    installed = await widget.controller.vencord
                                        .importCustomPluginFromSource(
                                      code,
                                      widget.controller.prefs,
                                    );
                                  }
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '已安裝並啟用插件：${installed.name}'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setM(() {
                                    loading = false;
                                    errText = '$e';
                                  });
                                }
                              },
                        child: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('安裝插件'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPluginSettingsModal(VencordPluginDef plugin, DiscordPalette p) {
    final vc = widget.controller.vencord;
    if (plugin.name == 'TextReplace') {
      _openTextReplaceEditorModal(p);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plugin.name,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (plugin.isCustom)
                        IconButton(
                          tooltip: '移除自訂插件',
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: DiscordPalette.danger),
                          onPressed: () async {
                            await vc.removeCustomPlugin(
                              plugin.name,
                              widget.controller.prefs,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                    ],
                  ),
                  Text(
                    '作者：${plugin.authors.join(', ')}',
                    style: TextStyle(color: p.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plugin.description,
                    style: TextStyle(color: p.textSecondary, fontSize: 13.5),
                  ),
                  if (plugin.commands.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '註冊斜線指令：${plugin.commands.map((c) => '/${c.name}').join(', ')}',
                      style: TextStyle(
                        color: p.brandColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Divider(height: 1, color: p.border),
                  const SizedBox(height: 8),
                  if (plugin.settings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '此外掛沒有額外可調整的設定項目。',
                        style: TextStyle(color: p.textMuted, fontSize: 13.5),
                      ),
                    )
                  else
                    ...plugin.settings.map((s) {
                      switch (s.type) {
                        case VencordOptionType.boolean:
                          final val = vc.getSetting<bool>(
                            plugin.name,
                            s.key,
                            s.resolvedDefault as bool? ?? false,
                          );
                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              s.key,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              s.description,
                              style:
                                  TextStyle(color: p.textMuted, fontSize: 12),
                            ),
                            value: val,
                            onChanged: (next) async {
                              await vc.setPluginSetting(
                                plugin.name,
                                s.key,
                                next,
                                widget.controller.prefs,
                              );
                              setM(() {});
                            },
                          );

                        case VencordOptionType.select:
                          final cur = vc.pluginSettings[plugin.name]?[s.key] ??
                              s.resolvedDefault;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.key,
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s.description,
                                  style: TextStyle(
                                      color: p.textMuted, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<Object>(
                                  value: s.options.any((o) => o.value == cur)
                                      ? cur
                                      : s.options.first.value,
                                  dropdownColor: p.cardBg,
                                  items: s.options
                                      .map((o) => DropdownMenuItem<Object>(
                                            value: o.value,
                                            child: Text(
                                              o.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (next) async {
                                    if (next == null) return;
                                    await vc.setPluginSetting(
                                      plugin.name,
                                      s.key,
                                      next,
                                      widget.controller.prefs,
                                    );
                                    setM(() {});
                                  },
                                ),
                              ],
                            ),
                          );

                        case VencordOptionType.number:
                        case VencordOptionType.string:
                          final curStr = (vc.pluginSettings[plugin.name]
                                      ?[s.key] ??
                                  s.resolvedDefault ??
                                  '')
                              .toString();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: TextFormField(
                              initialValue: curStr,
                              keyboardType: s.type == VencordOptionType.number
                                  ? TextInputType.number
                                  : TextInputType.text,
                              style:
                                  TextStyle(color: p.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: s.key,
                                helperText: s.description,
                                helperMaxLines: 2,
                                filled: true,
                                fillColor: p.elevatedBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (txt) {
                                final Object parsedVal =
                                    s.type == VencordOptionType.number
                                        ? (int.tryParse(txt.trim()) ??
                                            double.tryParse(txt.trim()) ??
                                            0)
                                        : txt;
                                vc.setPluginSetting(
                                  plugin.name,
                                  s.key,
                                  parsedVal,
                                  widget.controller.prefs,
                                );
                              },
                            ),
                          );
                      }
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openTextReplaceEditorModal(DiscordPalette p) {
    final vc = widget.controller.vencord;
    final rules = List<VencordTextRule>.from(vc.textReplaceRules);
    final findCtrl = TextEditingController();
    final repCtrl = TextEditingController();
    bool isRegex = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TextReplace 規則管理',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (rules.isEmpty)
                  Text(
                    '尚未新增任何自動文字取代規則。',
                    style: TextStyle(color: p.textMuted, fontSize: 13),
                  )
                else
                  ...rules.asMap().entries.map((entry) {
                    final r = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${r.isRegex ? "[Regex] " : ""}${r.find}  ->  ${r.replace}',
                        style: TextStyle(color: p.textPrimary, fontSize: 13.5),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: DiscordPalette.danger),
                        onPressed: () async {
                          rules.removeAt(entry.key);
                          await vc.updateTextReplaceRules(
                            rules,
                            widget.controller.prefs,
                          );
                          setM(() {});
                        },
                      ),
                    );
                  }),
                Divider(color: p.border),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: findCtrl,
                        decoration: const InputDecoration(hintText: '尋找文字 / Regex'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: repCtrl,
                        decoration: const InputDecoration(hintText: '取代為'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: isRegex,
                      onChanged: (v) => setM(() => isRegex = v ?? false),
                    ),
                    Text('使用正規表示式 (Regex)',
                        style: TextStyle(color: p.textSecondary, fontSize: 13)),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        if (findCtrl.text.isEmpty) return;
                        rules.add(VencordTextRule(
                          find: findCtrl.text,
                          replace: repCtrl.text,
                          isRegex: isRegex,
                        ));
                        findCtrl.clear();
                        repCtrl.clear();
                        await vc.updateTextReplaceRules(
                          rules,
                          widget.controller.prefs,
                        );
                        setM(() {});
                      },
                      child: const Text('新增規則'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);
        final vc = ctrl.vencord;

        final allPlugins = vc.allPlugins.where((pl) {
          final enabled = vc.isPluginEnabled(pl.name);
          if (_pluginFilter == 1 && !enabled) return false;
          if (_pluginFilter == 2 && enabled) return false;
          if (_pluginFilter == 3 && !pl.isCustom) return false;
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            return pl.name.toLowerCase().contains(q) ||
                pl.description.toLowerCase().contains(q) ||
                pl.tags.any((t) => t.toLowerCase().contains(q));
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: p.profileBg,
          appBar: AppBar(
            backgroundColor: p.profileBg,
            title: const Text('Vencord'),
            actions: [
              IconButton(
                tooltip: '安裝自訂 Vencord 插件',
                icon: const Icon(Icons.extension_rounded),
                onPressed: () => _openInstallCustomPluginModal(p),
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: p.brandColor,
              labelColor: p.textPrimary,
              unselectedLabelColor: p.textMuted,
              tabs: const [
                Tab(text: '插件 (Plugins)'),
                Tab(text: '主題與 CSS'),
                Tab(text: '備份與同步'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              // TAB 1: Plugins
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(color: p.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '搜尋 Vencord 插件...',
                        hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: p.textMuted, size: 19),
                        filled: true,
                        fillColor: p.sidebarBg,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        _filterChip(p, '全部 (${vc.allPlugins.length})', 0),
                        const SizedBox(width: 8),
                        _filterChip(p, '已啟用', 1),
                        const SizedBox(width: 8),
                        _filterChip(p, '已停用', 2),
                        const SizedBox(width: 8),
                        _filterChip(
                            p, '自訂外掛 (${vc.customPlugins.length})', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                      itemCount: allPlugins.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, idx) {
                        final pl = allPlugins[idx];
                        final enabled = vc.isPluginEnabled(pl.name);
                        final hasSettings = pl.settings.isNotEmpty ||
                            pl.name == 'TextReplace' ||
                            pl.isCustom;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openPluginSettingsModal(pl, p),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                            decoration: BoxDecoration(
                              color: p.sidebarBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: enabled
                                    ? p.brandColor.withAlpha(110)
                                    : p.border,
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              pl.name,
                                              style: TextStyle(
                                                color: p.textPrimary,
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (pl.required) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: p.brandColor,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '核心必備',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ] else if (pl.isCustom) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: DiscordPalette.green,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '自訂',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        pl.description,
                                        style: TextStyle(
                                          color: p.textSecondary,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'by ${pl.authors.join(', ')}',
                                        style: TextStyle(
                                          color: p.textMuted,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasSettings)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.settings_outlined,
                                      size: 20,
                                      color: p.textSecondary,
                                    ),
                                    onPressed: () =>
                                        _openPluginSettingsModal(pl, p),
                                  ),
                                Switch(
                                  value: enabled,
                                  onChanged: pl.required
                                      ? null
                                      : (v) => vc.setPluginEnabled(
                                            pl.name,
                                            v,
                                            ctrl.prefs,
                                          ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // TAB 2: Online Themes & QuickCSS
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: p.sidebarBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        '啟用 QuickCSS',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '套用自訂 Discord / Vencord CSS 色彩變數',
                        style: TextStyle(color: p.textMuted, fontSize: 12.5),
                      ),
                      value: _useQuickCss,
                      onChanged: (v) => setState(() => _useQuickCss = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '線上主題連結 (Online Themes / themeLinks)',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _themeLinksCtrl,
                    maxLines: 4,
                    style: const TextStyle(
                      color: Color(0xFFE3E5E8),
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText:
                          '每行一個 .theme.css 或 GitHub Raw CSS 網址\nhttps://raw.githubusercontent.com/.../theme.css',
                      hintStyle: TextStyle(color: p.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: p.sidebarBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: p.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QuickCSS (:root 變數)',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _quickCssCtrl,
                    maxLines: 8,
                    style: const TextStyle(
                      color: Color(0xFFE3E5E8),
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText:
                          ':root {\n  --background-primary: #101115;\n  --background-secondary: #14151a;\n  --brand-experiment: #5865f2;\n}',
                      hintStyle: TextStyle(color: p.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: p.sidebarBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: p.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          _themeLinksCtrl.clear();
                          _quickCssCtrl.clear();
                          await vc.updateThemesAndQuickCss(
                            nextUseQuickCss: true,
                            nextQuickCss: '',
                            nextThemeLinks: const [],
                            prefs: ctrl.prefs,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已重置為原版配色')),
                            );
                          }
                        },
                        child: const Text('重置配色'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: p.brandColor,
                          ),
                          onPressed: _applyingThemes
                              ? null
                              : () async {
                                  setState(() => _applyingThemes = true);
                                  await vc.updateThemesAndQuickCss(
                                    nextUseQuickCss: _useQuickCss,
                                    nextQuickCss: _quickCssCtrl.text,
                                    nextThemeLinks:
                                        _themeLinksCtrl.text.split('\n'),
                                    prefs: ctrl.prefs,
                                  );
                                  if (mounted) {
                                    setState(() => _applyingThemes = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('已套用 Vencord 主題與 CSS')),
                                    );
                                  }
                                },
                          icon: _applyingThemes
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const Text('儲存並套用主題'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // TAB 3: Vencord Backup & Restore (`vencord-settings-backup.json`)
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: p.sidebarBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vencord 設定備份與跨端同步',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '完全相容電腦版 DiscordBotClient / Vencord 的 vencord-settings-backup.json 格式（包含所有插件開關、參數設定、themeLinks 與 quickCss）。',
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: p.brandColor,
                            ),
                            onPressed: () {
                              final json = vc.exportVencordBackupJson();
                              Clipboard.setData(ClipboardData(text: json));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '已匯出 Vencord 備份 JSON 至剪貼簿'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.upload_file_rounded,
                                size: 18),
                            label: const Text('匯出 Vencord 設定 JSON (複製)'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showImportBackupDialog(p),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('匯入 Vencord 設定備份 JSON'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImportBackupDialog(DiscordPalette p) {
    final importCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.cardBg,
        title: const Text('匯入 Vencord 備份 JSON'),
        content: TextField(
          controller: importCtrl,
          maxLines: 8,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: '{"settings": {"plugins": {...}}, "quickCss": "..."}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await widget.controller.vencord.importVencordBackupJson(
                  importCtrl.text,
                  widget.controller.prefs,
                );
                _useQuickCss = widget.controller.vencord.useQuickCss;
                _themeLinksCtrl.text =
                    widget.controller.vencord.themeLinks.join('\n');
                _quickCssCtrl.text = widget.controller.vencord.quickCss;
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已成功匯入 Vencord 設定！')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('匯入失敗：$e')),
                  );
                }
              }
            },
            child: const Text('匯入'),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(DiscordPalette p, String label, int idx) {
    final selected = _pluginFilter == idx;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: p.brandColor.withAlpha(70),
      backgroundColor: p.sidebarBg,
      labelStyle: TextStyle(
        color: selected ? Colors.white : p.textSecondary,
        fontSize: 12.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => setState(() => _pluginFilter = idx),
    );
  }
}

// ============================================================================
// 2. ViewRaw Modal (`Vencord/src/plugins/viewRaw`)
// ============================================================================
void showVencordRawModal(
  BuildContext context, {
  required DiscordPalette palette,
  required String title,
  required Map<String, dynamic> data,
  String? rawContent,
  bool sortKeys = true,
}) {
  Object sortObj(Object? val) {
    if (!sortKeys || val == null) return val ?? '';
    if (val is List) return val.map(sortObj).toList();
    if (val is Map) {
      final keys = val.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: sortObj(val[k])};
    }
    return val;
  }

  final formattedJson =
      const JsonEncoder.withIndent('  ').convert(sortKeys ? sortObj(data) : data);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      builder: (_, sCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Raw $title Data',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (rawContent != null && rawContent.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: rawContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已複製原始文字內容')),
                      );
                    },
                    child: const Text('複製文字'),
                  ),
                FilledButton.tonal(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: formattedJson));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已複製 Raw JSON')),
                    );
                  },
                  child: const Text('複製 JSON'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.railBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: SingleChildScrollView(
                  controller: sCtrl,
                  child: SelectableText(
                    formattedJson,
                    style: const TextStyle(
                      color: Color(0xFFE3E5E8),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.38,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// 3. PermissionsViewer Modal (`Vencord/src/plugins/permissionsViewer`)
// ============================================================================
void showVencordPermissionsModal(
  BuildContext context, {
  required DiscordPalette palette,
  required String title,
  required BigInt permissions,
}) {
  final isAdmin =
      DiscordPermissions.has(permissions, DiscordPermissions.administrator);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (_, sCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '權限檢視器 — $title',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Permissions Bitfield: $permissions',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: palette.border),
            Expanded(
              child: ListView.separated(
                controller: sCtrl,
                itemCount: DiscordPermissions.namedFlags.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: palette.border),
                itemBuilder: (_, idx) {
                  final (label, bit) = DiscordPermissions.namedFlags[idx];
                  final granted =
                      isAdmin || DiscordPermissions.has(permissions, bit);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      granted
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: granted
                          ? DiscordPalette.green
                          : DiscordPalette.danger,
                      size: 19,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: granted
                            ? palette.textPrimary
                            : palette.textMuted,
                        fontSize: 14,
                        fontWeight:
                            granted ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// 4. ViewIcons Full-Resolution Viewer (`Vencord/src/plugins/viewIcons`)
// ============================================================================
void showVencordImageViewerModal(
  BuildContext context, {
  required DiscordPalette palette,
  required String title,
  required String imageUrl,
}) {
  final hiResUrl = imageUrl.replaceFirst(RegExp(r'size=\d+'), 'size=1024');
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: palette.profileBg,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: InteractiveViewer(
                  child: Image.network(
                    hiResUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hiResUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已複製高畫質圖片網址')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('複製網址'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    final uri = Uri.tryParse(hiResUrl);
                    if (uri != null) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('開啟原圖'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// 5. WhoReacted Sheet (`Vencord/src/plugins/whoReacted`)
// ============================================================================
void showWhoReactedSheet(
  BuildContext context, {
  required BotClientController controller,
  required DiscordPalette palette,
  required DiscordMessage message,
  required DiscordEmoji emoji,
  VoidCallback? onNavigateToDm,
}) {
  final rest = controller.rest;
  if (rest == null) return;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.56,
      maxChildSize: 0.88,
      builder: (_, sCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (emoji.imageUrl(size: 40) != null)
                  Image.network(emoji.imageUrl(size: 40)!, width: 22, height: 22)
                else
                  Text(emoji.name, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  '表情反應成員 (:${emoji.name}:)',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Expanded(
            child: FutureBuilder<List<DiscordUser>>(
              future: rest.getMessageReactionUsers(
                message.channelId,
                message.id,
                emoji.apiIdentifier,
              ),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snap.data ?? const [];
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      '目前沒有反應成員紀錄',
                      style: TextStyle(color: palette.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  controller: sCtrl,
                  itemCount: users.length,
                  itemBuilder: (_, idx) {
                    final u = users[idx];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(u.avatarUrl(size: 64)),
                      ),
                      title: Text(
                        u.displayName,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        u.tag,
                        style: TextStyle(
                            color: palette.textMuted, fontSize: 12),
                      ),
                      onTap: controller.vencord.getSetting<bool>(
                              'WhoReacted', 'clickableAvatars', true)
                          ? () {
                              Navigator.of(ctx).pop();
                              showUserProfileSheet(
                                context,
                                controller: controller,
                                initialUser: u,
                                guildId: message.guildId,
                                onNavigateToDm: onNavigateToDm,
                              );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// 6. Unified Emoji Picker with Application Emojis (`VencordDBCPlugin`)
// ============================================================================
void showDiscordEmojiPickerSheet(
  BuildContext context, {
  required BotClientController controller,
  required DiscordPalette palette,
  required DiscordGuild? guild,
  required void Function(DiscordEmoji emoji) onSelectEmoji,
}) {
  controller.loadApplicationEmojis();
  const commonUnicode = [
    '😀', '😂', '🥹', '😍', '🤔', '😎', '😭', '😡', '👍', '👎',
    '❤️', '🔥', '🎉', '✨', '💯', '👀', '🙏', '✅', '❌', '🚀',
  ];

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) {
        final appEmojis = controller.applicationEmojis;
        final guildEmojis = guild?.emojis ?? const <DiscordEmoji>[];
        final allowAnim = !controller.ecoSettings.ecoPowerSaving ||
            controller.vencord.isPluginEnabled('AlwaysAnimate');
        final botAcc = controller.activeAccount;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          maxChildSize: 0.90,
          builder: (_, sCtrl) => ListView(
            controller: sCtrl,
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Application Emojis Section (`VencordDBCPlugin/utils/application-emojis.ts`)
              if (appEmojis.isNotEmpty) ...[
                Row(
                  children: [
                    if (botAcc != null) ...[
                      CircleAvatar(
                        radius: 10,
                        backgroundImage:
                            NetworkImage(botAcc.avatarUrl(size: 32)),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      'Application Emojis (${appEmojis.length})',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: appEmojis.map((ae) {
                    final url = ae.imageUrl(size: 48, allowAnimated: allowAnim);
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onSelectEmoji(ae);
                      },
                      child: Tooltip(
                        message: ':${ae.name}:',
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: url != null
                              ? Image.network(url,
                                  width: 30, height: 30, cacheWidth: 60)
                              : Text(':${ae.name}:'),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ],

              // 2. Guild Custom Emojis
              if (guildEmojis.isNotEmpty) ...[
                Text(
                  '伺服器自訂表情 (${guildEmojis.length})',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: guildEmojis.map((ge) {
                    final url = ge.imageUrl(size: 48, allowAnimated: allowAnim);
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onSelectEmoji(ge);
                      },
                      child: Tooltip(
                        message: ':${ge.name}:',
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: url != null
                              ? Image.network(url,
                                  width: 30, height: 30, cacheWidth: 60)
                              : Text(':${ge.name}:'),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ],

              // 3. Standard Unicode Emojis
              Text(
                '常用表情',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: commonUnicode.map((em) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onSelectEmoji(DiscordEmoji(name: em));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(em, style: const TextStyle(fontSize: 25)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ============================================================================
// 7. SendTimestamps Picker Sheet (`Vencord/src/plugins/sendTimestamps`)
// ============================================================================
void showTimestampPickerSheet(
  BuildContext context, {
  required DiscordPalette palette,
  required void Function(String markdown) onInsert,
}) {
  DateTime chosen = DateTime.now();
  String style = 'f';
  const styles = [
    ('f', '完整日期與時間'),
    ('R', '相對時間 (幾分鐘前 / 後)'),
    ('t', '短時間 (HH:MM)'),
    ('T', '長時間 (HH:MM:SS)'),
    ('d', '短日期 (YYYY/MM/DD)'),
    ('D', '長日期'),
  ];

  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setM) {
        final unix = chosen.millisecondsSinceEpoch ~/ 1000;
        final md = '<t:$unix:$style>';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '插入動態時間戳記 (SendTimestamps)',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: chosen,
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2038),
                        );
                        if (d != null) {
                          setM(() {
                            chosen = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              chosen.hour,
                              chosen.minute,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label:
                          Text('${chosen.year}/${chosen.month}/${chosen.day}'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(chosen),
                        );
                        if (t != null) {
                          setM(() {
                            chosen = DateTime(
                              chosen.year,
                              chosen.month,
                              chosen.day,
                              t.hour,
                              t.minute,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text(
                        '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: styles.map((s) {
                    final sel = style == s.$1;
                    return ChoiceChip(
                      label: Text('${s.$2} (:${s.$1})'),
                      selected: sel,
                      onSelected: (_) => setM(() => style = s.$1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        md,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.brandColor,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onInsert('$md ');
                      },
                      child: const Text('插入'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ============================================================================
// 8. ShowHiddenChannels Lock Screen (`Vencord/src/plugins/showHiddenChannels`)
// ============================================================================
class HiddenChannelLockView extends StatelessWidget {
  final DiscordGuild guild;
  final DiscordChannel channel;
  final DiscordPalette palette;

  const HiddenChannelLockView({
    super.key,
    required this.guild,
    required this.channel,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final created = snowflakeCreatedAt(channel.id);
    final allowedRoles = <DiscordRole>[];
    for (final ow in channel.permissionOverwrites) {
      if (ow.type == 0 &&
          DiscordPermissions.has(ow.allow, DiscordPermissions.viewChannel)) {
        final r = guild.roles[ow.id];
        if (r != null) allowedRoles.add(r);
      }
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: palette.sidebarBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.cardBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 32,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '此為隱藏頻道 (#${channel.name})',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '目前機器人帳號沒有檢視此頻道的權限 (ShowHiddenChannels)。',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 13.5),
              ),
              if (channel.topic != null && channel.topic!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.cardBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    channel.topic!,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                '頻道建立日期：${created.year}年${created.month}月${created.day}日',
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
              if (allowedRoles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: allowedRoles.map((r) {
                    final c = r.color != 0
                        ? Color(0xFF000000 | r.color)
                        : const Color(0xFF99AAB5);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            r.name,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
