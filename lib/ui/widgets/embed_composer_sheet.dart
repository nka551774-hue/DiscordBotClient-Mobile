import 'dart:convert';
import 'package:flutter/material.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';
import 'discord_markdown.dart';
import 'message_components.dart';
import 'message_tile.dart';
import '../../l10n/strings.dart';

/// Visual Advanced Message Editor (VencordDBCPlugin EmbedEditor + Components V2
/// / raw JSON): sectioned form, live Discord-style preview, preset swatches and
/// a draggable HSV colour picker. Supports create and edit.
class EmbedComposerSheet extends StatefulWidget {
  final DiscordPalette palette;
  final DiscordEmbed? initialEmbed;
  final Map<String, dynamic>? initialRawMessage;
  final bool advancedDefault;
  final void Function(DiscordEmbed embed, String optionalContent) onSend;
  final void Function(Map<String, dynamic> rawPayload)? onSendRawPayload;

  /// Shown in the preview as the sending bot.
  final String? authorName;
  final String? authorAvatarUrl;

  const EmbedComposerSheet({
    super.key,
    required this.palette,
    this.initialEmbed,
    this.initialRawMessage,
    this.advancedDefault = false,
    required this.onSend,
    this.onSendRawPayload,
    this.authorName,
    this.authorAvatarUrl,
  });

  @override
  State<EmbedComposerSheet> createState() => _EmbedComposerSheetState();
}

const _presetColors = <int>[
  0x5865F2, 0x57F287, 0xFEE75C, 0xEB459E, 0xED4245, 0xFFFFFF, //
  0x3498DB, 0x1ABC9C, 0xE67E22, 0x9B59B6, 0x95A5A6, 0x2B2D31,
];

class _EmbedComposerSheetState extends State<EmbedComposerSheet> {
  late bool _jsonMode;
  bool _preview = false;
  bool _componentsV2Flag = false;
  late final TextEditingController _rawJsonCtrl;
  String? _jsonError;

  late final TextEditingController _contentCtrl;
  late final TextEditingController _authorNameCtrl;
  late final TextEditingController _authorIconCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _thumbUrlCtrl;
  late final TextEditingController _footerTitleCtrl;
  late final TextEditingController _footerIconCtrl;
  late int _color;
  bool _footerTimestamp = false;
  final List<_EmbedFieldDraft> _fields = <_EmbedFieldDraft>[];

  @override
  void initState() {
    super.initState();
    final init = widget.initialEmbed;
    final rawMsg = widget.initialRawMessage;
    _componentsV2Flag =
        rawMsg != null && ((rawMsg['flags'] as int? ?? 0) & (1 << 15)) != 0;
    _jsonMode = _componentsV2Flag || (rawMsg != null && init == null);

    final defaultJsonMap = rawMsg != null
        ? <String, dynamic>{
            if (rawMsg['content'] != null) 'content': rawMsg['content'],
            if (rawMsg['embeds'] != null) 'embeds': rawMsg['embeds'],
            if (rawMsg['components'] != null &&
                (rawMsg['components'] as List).isNotEmpty)
              'components': rawMsg['components'],
            if (_componentsV2Flag) 'flags': 32768,
          }
        : <String, dynamic>{
            'content': '',
            'embeds': [
              if (init != null)
                init.toJson()
              else
                {
                  'title': 'Embed Title',
                  'description': 'Write something...',
                  'color': 5793266,
                },
            ],
          };
    _rawJsonCtrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(defaultJsonMap),
    );

    _contentCtrl =
        TextEditingController(text: rawMsg?['content']?.toString() ?? '');
    _authorNameCtrl = TextEditingController(text: init?.authorName ?? '');
    _authorIconCtrl = TextEditingController(text: init?.authorIconUrl ?? '');
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _urlCtrl = TextEditingController(text: init?.url ?? '');
    _descCtrl = TextEditingController(text: init?.description ?? '');
    _color = init?.color ?? 0x5865F2;
    _imageUrlCtrl = TextEditingController(text: init?.imageUrl ?? '');
    _thumbUrlCtrl = TextEditingController(text: init?.thumbnailUrl ?? '');
    _footerTitleCtrl = TextEditingController(text: init?.footerText ?? '');
    _footerIconCtrl = TextEditingController(text: init?.footerIconUrl ?? '');
    _footerTimestamp = init?.timestamp != null;

    if (init != null && init.fields.isNotEmpty) {
      for (final f in init.fields) {
        _fields.add(_EmbedFieldDraft(
          name: f.name,
          value: f.value,
          inline: f.inline,
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _rawJsonCtrl,
      _contentCtrl,
      _authorNameCtrl,
      _authorIconCtrl,
      _titleCtrl,
      _urlCtrl,
      _descCtrl,
      _imageUrlCtrl,
      _thumbUrlCtrl,
      _footerTitleCtrl,
      _footerIconCtrl,
    ]) {
      c.dispose();
    }
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  DiscordEmbed _buildEmbed() {
    String? v(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return DiscordEmbed(
      authorName: v(_authorNameCtrl),
      authorIconUrl: v(_authorIconCtrl),
      title: v(_titleCtrl),
      url: v(_urlCtrl),
      description: v(_descCtrl),
      color: _color,
      imageUrl: v(_imageUrlCtrl),
      thumbnailUrl: v(_thumbUrlCtrl),
      footerText: v(_footerTitleCtrl),
      footerIconUrl: v(_footerIconCtrl),
      timestamp:
          _footerTimestamp ? DateTime.now().toUtc().toIso8601String() : null,
      fields: _fields
          .where((f) =>
              f.nameCtrl.text.trim().isNotEmpty &&
              f.valueCtrl.text.trim().isNotEmpty)
          .map((f) => DiscordEmbedField(
                name: f.nameCtrl.text.trim(),
                value: f.valueCtrl.text.trim(),
                inline: f.inline,
              ))
          .toList(),
    );
  }

  bool _embedIsEmpty(DiscordEmbed e) =>
      e.authorName == null &&
      e.title == null &&
      e.description == null &&
      e.imageUrl == null &&
      e.thumbnailUrl == null &&
      e.footerText == null &&
      e.fields.isEmpty;

  void _submit() {
    if (_jsonMode && widget.onSendRawPayload != null) {
      try {
        final decoded = jsonDecode(_rawJsonCtrl.text);
        if (decoded is! Map<String, dynamic>) {
          setState(() => _jsonError = tr('Payload 必須為 JSON 物件 {}'));
          return;
        }
        final map = Map<String, dynamic>.from(decoded);
        if (_componentsV2Flag) {
          map['flags'] = (map['flags'] as int? ?? 0) | (1 << 15);
        }
        Navigator.of(context).pop();
        widget.onSendRawPayload!(map);
      } catch (e) {
        setState(() => _jsonError = trf('JSON 語法錯誤：{0}', [e]));
      }
      return;
    }
    final embed = _buildEmbed();
    if (_embedIsEmpty(embed)) return;
    Navigator.of(context).pop();
    widget.onSend(embed, _contentCtrl.text.trim());
  }

  // ---------------------------------------------------------------- preview
  Widget _previewMessage(DiscordPalette p) {
    String content = '';
    List<DiscordEmbed> embeds = const [];
    List<dynamic> components = const [];
    String? error;
    if (_jsonMode) {
      try {
        final decoded = jsonDecode(_rawJsonCtrl.text);
        if (decoded is Map) {
          content = decoded['content']?.toString() ?? '';
          embeds = [
            for (final e in (decoded['embeds'] as List?) ?? const [])
              if (e is Map<String, dynamic>) DiscordEmbed.fromJson(e),
          ];
          components = (decoded['components'] as List?) ?? const [];
        } else {
          error = tr('Payload 必須為 JSON 物件 {}');
        }
      } catch (e) {
        error = trf('JSON 語法錯誤：{0}', [e]);
      }
    } else {
      content = _contentCtrl.text.trim();
      final e = _buildEmbed();
      embeds = _embedIsEmpty(e) ? const [] : [e];
    }

    final now = DateTime.now();
    final time =
        trf('今天 {0}:{1}', [now.hour.toString().padLeft(2, '0'), now.minute.toString().padLeft(2, '0')]);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: p.chatBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: DiscordPalette.blurple,
            backgroundImage: widget.authorAvatarUrl != null
                ? NetworkImage(widget.authorAvatarUrl!)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      widget.authorName ?? 'Bot',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4.5, vertical: 1),
                      decoration: BoxDecoration(
                        color: DiscordPalette.blurple,
                        borderRadius: BorderRadius.circular(3.5),
                      ),
                      child: const Text(
                        'APP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(time,
                        style: TextStyle(color: p.textMuted, fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 3),
                if (error != null)
                  Text(error,
                      style: const TextStyle(
                          color: DiscordPalette.red, fontSize: 12.5))
                else ...[
                  if (content.isNotEmpty)
                    DiscordMarkdownView(
                      text: content,
                      palette: p,
                      ecoMode: false,
                    ),
                  for (final e in embeds)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: DiscordEmbedPreview(embed: e, palette: p),
                    ),
                  if (components.isNotEmpty)
                    DiscordComponentsView(
                      components: components,
                      attachments: const [],
                      palette: p,
                      ecoMode: false,
                      onOpenMedia: (_, __) {},
                    ),
                  if (content.isEmpty && embeds.isEmpty && components.isEmpty)
                    Text(tr('（尚無內容）'),
                        style: TextStyle(color: p.textMuted, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- colour
  Future<void> _openColorPicker() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(
        initial: _color,
        palette: widget.palette,
      ),
    );
    if (picked != null) setState(() => _color = picked);
  }

  Widget _colorSection(DiscordPalette p) {
    final custom = !_presetColors.contains(_color);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in _presetColors)
          GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color(0xFF000000 | c),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _color == c ? Colors.white : p.border,
                  width: _color == c ? 2.5 : 1,
                ),
              ),
              child: _color == c
                  ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Color(0xFF000000 | c).computeLuminance() > 0.6
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        GestureDetector(
          onTap: _openColorPicker,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: custom ? Color(0xFF000000 | _color) : null,
              gradient: custom
                  ? null
                  : const SweepGradient(colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ]),
              border: Border.all(
                color: custom ? Colors.white : p.border,
                width: custom ? 2.5 : 1,
              ),
            ),
            child: const Icon(Icons.colorize_rounded,
                size: 17, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- form
  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit =
        widget.initialEmbed != null || widget.initialRawMessage != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: p.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        _jsonMode
                            ? tr('進階訊息編輯器')
                            : (isEdit ? tr('編輯嵌入訊息') : tr('建立嵌入訊息')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.brandColor,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _submit,
                      child: Text(isEdit ? tr('儲存') : tr('傳送')),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.edit_rounded, size: 17),
                            label: Text(tr('編輯')),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.visibility_rounded, size: 17),
                            label: Text(tr('預覽')),
                          ),
                        ],
                        selected: {_preview},
                        onSelectionChanged: (s) =>
                            setState(() => _preview = s.first),
                      ),
                    ),
                    if (widget.onSendRawPayload != null) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: _jsonMode ? tr('表單模式') : 'JSON / Components V2',
                        onPressed: () => setState(() {
                          _jsonError = null;
                          _jsonMode = !_jsonMode;
                        }),
                        icon: Icon(
                          _jsonMode
                              ? Icons.dashboard_customize_rounded
                              : Icons.data_object_rounded,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: p.border),
              Expanded(
                child: _preview
                    ? ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(14),
                        children: [_previewMessage(p)],
                      )
                    : (_jsonMode
                        ? _buildJsonEditor(p, scrollCtrl)
                        : _buildForm(p, scrollCtrl)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJsonEditor(DiscordPalette p, ScrollController scrollCtrl) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(14),
      children: [
        _section(
          p,
          icon: Icons.view_quilt_rounded,
          title: 'Components V2',
          children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr('啟用 Components V2 (IS_COMPONENTS_V2 = 32768)'),
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                tr('相容 Discohook 與 Discord Components V2 容器結構'),
                style: TextStyle(color: p.textMuted, fontSize: 12),
              ),
              value: _componentsV2Flag,
              onChanged: (v) => setState(() => _componentsV2Flag = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_jsonError != null) ...[
          Text(
            _jsonError!,
            style: const TextStyle(color: DiscordPalette.red, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _rawJsonCtrl,
          maxLines: 20,
          onChanged: (_) {
            if (_jsonError != null) setState(() => _jsonError = null);
          },
          style: const TextStyle(
            color: Color(0xFFE3E5E8),
            fontSize: 12.5,
            fontFamily: 'monospace',
            height: 1.4,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: p.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: p.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(DiscordPalette p, ScrollController scrollCtrl) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(14),
      children: [
        _section(p, icon: Icons.chat_rounded, title: tr('訊息內容'), children: [
          _input(p, _contentCtrl, tr('嵌入上方的一般文字（選填）'),
              maxLines: 3, maxLength: 2000),
        ]),
        const SizedBox(height: 10),
        _section(p, icon: Icons.palette_rounded, title: tr('顏色'), children: [
          _colorSection(p),
          const SizedBox(height: 8),
          Text(
            '#${_color.toRadixString(16).padLeft(6, '0').toUpperCase()}',
            style: TextStyle(
              color: p.textSecondary,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _section(p, icon: Icons.person_rounded, title: tr('作者'), children: [
          _input(p, _authorNameCtrl, tr('作者名稱'), maxLength: 256),
          const SizedBox(height: 8),
          _urlInput(p, _authorIconCtrl, tr('作者頭像網址')),
        ]),
        const SizedBox(height: 10),
        _section(p, icon: Icons.title_rounded, title: tr('內文'), children: [
          _input(p, _titleCtrl, tr('標題'), maxLength: 256),
          const SizedBox(height: 8),
          _input(p, _urlCtrl, tr('標題連結 https://…')),
          const SizedBox(height: 8),
          _input(p, _descCtrl, tr('描述（支援 Markdown）'),
              maxLines: 5, maxLength: 4096),
        ]),
        const SizedBox(height: 10),
        _section(p, icon: Icons.view_column_rounded, title: tr('欄位'), children: [
          for (var i = 0; i < _fields.length; i++) _fieldEditor(p, i),
          if (_fields.length < 25)
            OutlinedButton.icon(
              onPressed: () => setState(() => _fields.add(_EmbedFieldDraft())),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(tr('新增欄位')),
            ),
        ]),
        const SizedBox(height: 10),
        _section(p, icon: Icons.image_rounded, title: tr('圖片'), children: [
          _urlInput(p, _imageUrlCtrl, tr('大圖網址')),
          const SizedBox(height: 8),
          _urlInput(p, _thumbUrlCtrl, tr('縮圖網址（右上角）')),
        ]),
        const SizedBox(height: 10),
        _section(p, icon: Icons.short_text_rounded, title: tr('頁尾'), children: [
          _input(p, _footerTitleCtrl, tr('頁尾文字'), maxLength: 2048),
          const SizedBox(height: 8),
          _urlInput(p, _footerIconCtrl, tr('頁尾圖示網址')),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(tr('顯示時間戳記'),
                style: TextStyle(color: p.textPrimary, fontSize: 13.5)),
            value: _footerTimestamp,
            onChanged: (v) => setState(() => _footerTimestamp = v),
          ),
        ]),
      ],
    );
  }

  Widget _fieldEditor(DiscordPalette p, int idx) {
    final f = _fields[idx];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.elevatedBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                trf('欄位 {0}', [idx + 1]),
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilterChip(
                label: Text(tr('並排')),
                selected: f.inline,
                onSelected: (v) => setState(() => f.inline = v),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: DiscordPalette.danger),
                onPressed: () => setState(() {
                  f.dispose();
                  _fields.removeAt(idx);
                }),
              ),
            ],
          ),
          _input(p, f.nameCtrl, tr('欄位名稱'), maxLength: 256),
          const SizedBox(height: 6),
          _input(p, f.valueCtrl, tr('欄位內容'), maxLines: 3, maxLength: 1024),
        ],
      ),
    );
  }

  Widget _section(
    DiscordPalette p, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.sidebarBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: Color(0xFF000000 | _color), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: p.textSecondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  /// URL input with a live thumbnail of the linked image.
  Widget _urlInput(
    DiscordPalette p,
    TextEditingController ctrl,
    String hint,
  ) {
    final url = ctrl.text.trim();
    final ok = url.startsWith('http');
    return Row(
      children: [
        Expanded(child: _input(p, ctrl, hint)),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 40,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.elevatedBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ok
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image_outlined,
                      size: 18,
                      color: p.textMuted),
                )
              : Icon(Icons.image_outlined, size: 18, color: p.textMuted),
        ),
      ],
    );
  }

  Widget _input(
    DiscordPalette p,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: ctrl,
      minLines: 1,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: p.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.textMuted, fontSize: 13.5),
        filled: true,
        fillColor: p.inputBg,
        isDense: true,
        counterStyle: TextStyle(color: p.textMuted, fontSize: 10.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Saturation/value square + hue bar you can drag, with live hex.
class _ColorPickerDialog extends StatefulWidget {
  final int initial;
  final DiscordPalette palette;

  const _ColorPickerDialog({required this.initial, required this.palette});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(Color(0xFF000000 | widget.initial));
    _hexCtrl = TextEditingController(text: _hex);
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  int get _rgb => _hsv.toColor().value & 0xFFFFFF;
  String get _hex => _rgb.toRadixString(16).padLeft(6, '0').toUpperCase();

  void _set(HSVColor next) {
    setState(() {
      _hsv = next;
      _hexCtrl.text = _hex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    return AlertDialog(
      backgroundColor: p.cardBg,
      title: Text(tr('自訂顏色')),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Saturation (x) / value (y) square
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              const h = 190.0;
              void pick(Offset o) => _set(_hsv
                  .withSaturation((o.dx / w).clamp(0.0, 1.0))
                  .withValue(1 - (o.dy / h).clamp(0.0, 1.0)));
              return GestureDetector(
                onPanDown: (d) => pick(d.localPosition),
                onPanUpdate: (d) => pick(d.localPosition),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [Colors.white, hueColor],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xFF000000)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _hsv.saturation * w - 11,
                        top: (1 - _hsv.value) * h - 11,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _hsv.toColor(),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Color(0x88000000), blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            // Hue bar
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              void pick(Offset o) =>
                  _set(_hsv.withHue((o.dx / w).clamp(0.0, 1.0) * 359.9));
              return GestureDetector(
                onPanDown: (d) => pick(d.localPosition),
                onPanUpdate: (d) => pick(d.localPosition),
                child: SizedBox(
                  width: w,
                  height: 26,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        top: 4,
                        bottom: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            gradient: const LinearGradient(colors: [
                              Color(0xFFFF0000),
                              Color(0xFFFFFF00),
                              Color(0xFF00FF00),
                              Color(0xFF00FFFF),
                              Color(0xFF0000FF),
                              Color(0xFFFF00FF),
                              Color(0xFFFF0000),
                            ]),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _hsv.hue / 360 * w - 13,
                        top: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: hueColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _hsv.toColor(),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexCtrl,
                    maxLength: 6,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      prefixText: '#',
                      counterText: '',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v, radix: 16);
                      if (v.length == 6 && n != null) {
                        setState(() =>
                            _hsv = HSVColor.fromColor(Color(0xFF000000 | n)));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_rgb),
          child: Text(tr('套用')),
        ),
      ],
    );
  }
}

class _EmbedFieldDraft {
  final TextEditingController nameCtrl;
  final TextEditingController valueCtrl;
  bool inline;

  _EmbedFieldDraft({
    String name = '',
    String value = '',
    this.inline = false,
  })  : nameCtrl = TextEditingController(text: name),
        valueCtrl = TextEditingController(text: value);

  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
  }
}
