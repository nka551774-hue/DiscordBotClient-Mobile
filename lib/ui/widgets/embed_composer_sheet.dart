import 'dart:convert';
import 'package:flutter/material.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';

/// 1:1 recreation of VencordDBCPlugin/components/EmbedEditor.tsx + Advanced Message Editor (Components V2 / Raw JSON)!
/// Supports BOTH Create mode and Edit mode for existing bot embeds & Components V2 payloads.
class EmbedComposerSheet extends StatefulWidget {
  final DiscordPalette palette;
  final DiscordEmbed? initialEmbed;
  final Map<String, dynamic>? initialRawMessage;
  final bool advancedDefault;
  final void Function(DiscordEmbed embed, String optionalContent) onSend;
  final void Function(Map<String, dynamic> rawPayload)? onSendRawPayload;

  const EmbedComposerSheet({
    super.key,
    required this.palette,
    this.initialEmbed,
    this.initialRawMessage,
    this.advancedDefault = false,
    required this.onSend,
    this.onSendRawPayload,
  });

  @override
  State<EmbedComposerSheet> createState() => _EmbedComposerSheetState();
}

class _EmbedComposerSheetState extends State<EmbedComposerSheet> {
  late bool _jsonMode;
  bool _componentsV2Flag = false;
  late final TextEditingController _rawJsonCtrl;
  String? _jsonError;

  late final TextEditingController _authorNameCtrl;
  late final TextEditingController _authorIconCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _colorHexCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _thumbUrlCtrl;
  late final TextEditingController _footerTitleCtrl;
  late final TextEditingController _footerIconCtrl;
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

    _authorNameCtrl = TextEditingController(text: init?.authorName ?? '');
    _authorIconCtrl = TextEditingController(text: init?.authorIconUrl ?? '');
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _urlCtrl = TextEditingController(text: init?.url ?? '');
    _descCtrl = TextEditingController(text: init?.description ?? '');
    final initColor = init?.color != null
        ? '#${init!.color!.toRadixString(16).padLeft(6, '0').toUpperCase()}'
        : '#5865F2';
    _colorHexCtrl = TextEditingController(text: initColor);
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
    } else {
      _fields.add(_EmbedFieldDraft());
    }
  }

  @override
  void dispose() {
    _rawJsonCtrl.dispose();
    _authorNameCtrl.dispose();
    _authorIconCtrl.dispose();
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _descCtrl.dispose();
    _colorHexCtrl.dispose();
    _imageUrlCtrl.dispose();
    _thumbUrlCtrl.dispose();
    _footerTitleCtrl.dispose();
    _footerIconCtrl.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  int? _parseColor() {
    final raw = _colorHexCtrl.text.trim().replaceAll('#', '');
    if (raw.length == 6) {
      return int.tryParse(raw, radix: 16);
    }
    return 0x5865F2;
  }

  void _submit() {
    if (_jsonMode && widget.onSendRawPayload != null) {
      try {
        final decoded = jsonDecode(_rawJsonCtrl.text);
        if (decoded is! Map<String, dynamic>) {
          setState(() => _jsonError = 'Payload 必須為 JSON 物件 {}');
          return;
        }
        final map = Map<String, dynamic>.from(decoded);
        if (_componentsV2Flag) {
          map['flags'] = (map['flags'] as int? ?? 0) | (1 << 15);
        }
        Navigator.of(context).pop();
        widget.onSendRawPayload!(map);
      } catch (e) {
        setState(() => _jsonError = 'JSON 語法錯誤：$e');
      }
      return;
    }

    final validFields = _fields
        .where((f) =>
            f.nameCtrl.text.trim().isNotEmpty &&
            f.valueCtrl.text.trim().isNotEmpty)
        .map((f) => DiscordEmbedField(
              name: f.nameCtrl.text.trim(),
              value: f.valueCtrl.text.trim(),
              inline: f.inline,
            ))
        .toList();

    if (_authorNameCtrl.text.trim().isEmpty &&
        _titleCtrl.text.trim().isEmpty &&
        _descCtrl.text.trim().isEmpty &&
        _imageUrlCtrl.text.trim().isEmpty &&
        _thumbUrlCtrl.text.trim().isEmpty &&
        _footerTitleCtrl.text.trim().isEmpty &&
        validFields.isEmpty) {
      return;
    }

    final embed = DiscordEmbed(
      authorName: _authorNameCtrl.text.trim(),
      authorIconUrl: _authorIconCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      color: _parseColor(),
      imageUrl: _imageUrlCtrl.text.trim(),
      thumbnailUrl: _thumbUrlCtrl.text.trim(),
      footerText: _footerTitleCtrl.text.trim(),
      footerIconUrl: _footerIconCtrl.text.trim(),
      timestamp:
          _footerTimestamp ? DateTime.now().toUtc().toIso8601String() : null,
      fields: validFields,
    );

    Navigator.of(context).pop();
    widget.onSend(embed, '');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.initialEmbed != null || widget.initialRawMessage != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _jsonMode
                            ? (isEdit
                                ? 'Advanced Message Editor'
                                : 'Advanced Message Editor')
                            : (isEdit ? 'Edit Embed' : 'Create Embed'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.onSendRawPayload != null)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _jsonError = null;
                          _jsonMode = !_jsonMode;
                        }),
                        icon: Icon(
                          _jsonMode
                              ? Icons.dashboard_customize_outlined
                              : Icons.data_object_rounded,
                          size: 16,
                        ),
                        label: Text(_jsonMode ? '表單模式' : 'JSON / V2'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel',
                          style: TextStyle(color: p.textSecondary)),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.brandColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: _submit,
                      child: Text(isEdit ? 'Save' : 'Send'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.border),
              Expanded(
                child: _jsonMode
                    ? ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(14),
                        children: [
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '啟用 Components V2 (IS_COMPONENTS_V2 = 32768)',
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '相容 Discohook 與 Discord Components V2 容器結構',
                              style:
                                  TextStyle(color: p.textMuted, fontSize: 12),
                            ),
                            value: _componentsV2Flag,
                            onChanged: (v) =>
                                setState(() => _componentsV2Flag = v),
                          ),
                          if (_jsonError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _jsonError!,
                              style: const TextStyle(
                                color: DiscordPalette.red,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            controller: _rawJsonCtrl,
                            maxLines: 18,
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
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: p.border),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(14),
                  children: [
                    _sectionCard(p, 'Author', [
                      _labeledInput(p, 'Name', _authorNameCtrl, 'Author name'),
                      const SizedBox(height: 10),
                      _labeledInput(p, 'Icon URL', _authorIconCtrl,
                          'https://i.imgur.com/image.png'),
                    ]),
                    const SizedBox(height: 12),
                    _sectionCard(p, 'Body', [
                      _labeledInput(p, 'Title', _titleCtrl, 'Embed title'),
                      const SizedBox(height: 10),
                      _labeledInput(p, 'URL', _urlCtrl, 'https://discord.com'),
                      const SizedBox(height: 10),
                      _labeledInput(
                        p,
                        'Description',
                        _descCtrl,
                        'Write something...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      _labeledInput(p, 'Color (Hex)', _colorHexCtrl, '#5865F2'),
                    ]),
                    const SizedBox(height: 12),
                    _sectionCard(p, 'Images', [
                      _labeledInput(p, 'Image URL', _imageUrlCtrl,
                          'https://i.imgur.com/image.png'),
                      const SizedBox(height: 10),
                      _labeledInput(p, 'Thumbnail URL', _thumbUrlCtrl,
                          'https://i.imgur.com/image.png'),
                    ]),
                    const SizedBox(height: 12),
                    _sectionCard(p, 'Fields', [
                      ..._fields.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final f = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _rawInput(p, f.nameCtrl, 'Name'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _rawInput(p, f.valueCtrl, 'Value'),
                                  ),
                                  if (_fields.length > 1)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18,
                                          color: DiscordPalette.danger),
                                      onPressed: () {
                                        setState(() {
                                          f.dispose();
                                          _fields.removeAt(idx);
                                        });
                                      },
                                    ),
                                ],
                              ),
                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('Inline',
                                    style: TextStyle(
                                        color: p.textSecondary, fontSize: 13)),
                                value: f.inline,
                                onChanged: (v) => setState(() => f.inline = v),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (_fields.length < 25)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _fields.add(_EmbedFieldDraft())),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Field'),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    _sectionCard(p, 'Footer', [
                      _labeledInput(
                          p, 'Title', _footerTitleCtrl, 'Footer text'),
                      const SizedBox(height: 10),
                      _labeledInput(p, 'Image URL', _footerIconCtrl,
                          'https://i.imgur.com/image.png'),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Timestamp',
                            style: TextStyle(
                                color: p.textPrimary, fontSize: 13.5)),
                        subtitle: Text(
                          'Displays the current time for embeds',
                          style: TextStyle(color: p.textMuted, fontSize: 12),
                        ),
                        value: _footerTimestamp,
                        onChanged: (v) => setState(() => _footerTimestamp = v),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionCard(
    DiscordPalette p,
    String heading,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.sidebarBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _labeledInput(
    DiscordPalette p,
    String label,
    TextEditingController ctrl,
    String placeholder, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: p.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        _rawInput(p, ctrl, placeholder, maxLines: maxLines),
      ],
    );
  }

  Widget _rawInput(
    DiscordPalette p,
    TextEditingController ctrl,
    String placeholder, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: p.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: p.textMuted, fontSize: 13.5),
        filled: true,
        fillColor: const Color(0xFF1E1F22),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
      ),
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
