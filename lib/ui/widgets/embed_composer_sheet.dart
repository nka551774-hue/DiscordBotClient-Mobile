import 'package:flutter/material.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';

/// 1:1 recreation of VencordDBCPlugin/components/EmbedEditor.tsx
class EmbedComposerSheet extends StatefulWidget {
  final DiscordPalette palette;
  final void Function(DiscordEmbed embed, String optionalContent) onSend;

  const EmbedComposerSheet({
    super.key,
    required this.palette,
    required this.onSend,
  });

  @override
  State<EmbedComposerSheet> createState() => _EmbedComposerSheetState();
}

class _EmbedComposerSheetState extends State<EmbedComposerSheet> {
  final _authorNameCtrl = TextEditingController();
  final _authorIconCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _colorHexCtrl = TextEditingController(text: '#5865F2');
  final _imageUrlCtrl = TextEditingController();
  final _thumbUrlCtrl = TextEditingController();
  final _footerTitleCtrl = TextEditingController();
  final _footerIconCtrl = TextEditingController();
  bool _footerTimestamp = false;
  final List<_EmbedFieldDraft> _fields = <_EmbedFieldDraft>[
    _EmbedFieldDraft(),
  ];

  @override
  void dispose() {
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
    var raw = _colorHexCtrl.text.trim().replaceAll('#', '');
    if (raw.length == 6) {
      return int.tryParse(raw, radix: 16);
    }
    return 0x5865F2;
  }

  void _submit() {
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
              // Modal Header matching EmbedEditorModal
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    Text(
                      'Create Embed',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel',
                          style: TextStyle(color: p.textSecondary)),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DiscordPalette.blurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: _submit,
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.border),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(14),
                  children: [
                    // Author Card
                    _sectionCard(p, 'Author', [
                      _labeledInput(p, 'Name', _authorNameCtrl, 'Author name'),
                      const SizedBox(height: 10),
                      _labeledInput(p, 'Icon URL', _authorIconCtrl,
                          'https://i.imgur.com/image.png'),
                    ]),
                    const SizedBox(height: 12),

                    // Body Card
                    _sectionCard(p, 'Body', [
                      _labeledInput(p, 'Title', _titleCtrl, 'Embed title'),
                      const SizedBox(height: 10),
                      _labeledInput(
                          p, 'URL', _urlCtrl, 'https://discord.com'),
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

                    // Images Card
                    _sectionCard(p, 'Images', [
                      _labeledInput(p, 'Image URL', _imageUrlCtrl,
                          'https://i.imgur.com/image.png'),
                      const SizedBox(height: 10),
                      _labeledInput(p, 'Thumbnail URL', _thumbUrlCtrl,
                          'https://i.imgur.com/image.png'),
                    ]),
                    const SizedBox(height: 12),

                    // Fields Card
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
                                    child: _rawInput(
                                        p, f.nameCtrl, 'Name'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _rawInput(
                                        p, f.valueCtrl, 'Value'),
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
                                onChanged: (v) =>
                                    setState(() => f.inline = v),
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

                    // Footer Card
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
                            style:
                                TextStyle(color: p.textPrimary, fontSize: 13.5)),
                        subtitle: Text(
                          'Displays the current time for new embeds',
                          style: TextStyle(color: p.textMuted, fontSize: 12),
                        ),
                        value: _footerTimestamp,
                        onChanged: (v) =>
                            setState(() => _footerTimestamp = v),
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
        color: p.elevatedBg,
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
  final nameCtrl = TextEditingController();
  final valueCtrl = TextEditingController();
  bool inline = false;

  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
  }
}
