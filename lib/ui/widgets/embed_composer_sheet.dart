import 'package:flutter/material.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';

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
  final _contentCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final List<_EditableField> _fields = <_EditableField>[];

  int _selectedColor = 0x5865F2;

  static const List<int> _presetColors = [
    0x5865F2, // Blurple
    0x23A55A, // Green
    0xF0B232, // Yellow
    0xF23F43, // Red
    0xEB459E, // Fuchsia
    0x00A8FC, // Cyan
    0xFFFFFF, // White
  ];

  @override
  void dispose() {
    _contentCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _imageUrlCtrl.dispose();
    _footerCtrl.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty &&
        _descCtrl.text.trim().isEmpty &&
        _imageUrlCtrl.text.trim().isEmpty &&
        _fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少填寫標題、描述、欄位或圖片網址其中一項')),
      );
      return;
    }

    final embed = DiscordEmbed(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      color: _selectedColor,
      imageUrl: _imageUrlCtrl.text.trim(),
      footerText: _footerCtrl.text.trim(),
      timestamp: DateTime.now().toUtc().toIso8601String(),
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

    Navigator.of(context).pop();
    widget.onSend(embed, _contentCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: bottomInset + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_mosaic_rounded,
                    color: DiscordPalette.blurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  '發送機器人專屬 Rich Embed',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: p.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presetColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, idx) {
                  final c = _presetColors[idx];
                  final selected = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(0xFF000000 | c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 16, color: Colors.black)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildField(_contentCtrl, '附加一般文字訊息 (選填)', p),
            const SizedBox(height: 8),
            _buildField(_titleCtrl, 'Embed 標題 (Title)', p),
            const SizedBox(height: 8),
            _buildField(_descCtrl, 'Embed 內容描述 (支援 Markdown)', p, maxLines: 3),
            const SizedBox(height: 8),
            _buildField(_imageUrlCtrl, '圖片網址 Image URL (選填)', p),
            const SizedBox(height: 8),
            _buildField(_footerCtrl, '頁尾文字 Footer (選填)', p),
            const SizedBox(height: 10),
            ..._fields.asMap().entries.map((entry) {
              final i = entry.key;
              final f = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('欄位 #${i + 1}',
                            style: TextStyle(
                                color: p.textSecondary, fontSize: 12)),
                        const Spacer(),
                        Row(
                          children: [
                            Text('並排',
                                style:
                                    TextStyle(color: p.textMuted, fontSize: 12)),
                            Switch(
                              value: f.inline,
                              onChanged: (v) => setState(() => f.inline = v),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: DiscordPalette.red),
                          onPressed: () {
                            setState(() {
                              f.dispose();
                              _fields.removeAt(i);
                            });
                          },
                        ),
                      ],
                    ),
                    _buildField(f.nameCtrl, '欄位名稱', p),
                    const SizedBox(height: 6),
                    _buildField(f.valueCtrl, '欄位內容', p),
                  ],
                ),
              );
            }),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _fields.length >= 8
                      ? null
                      : () => setState(() => _fields.add(_EditableField())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新增欄位'),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: DiscordPalette.blurple,
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('傳送 Embed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint,
    DiscordPalette p, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: p.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.textMuted, fontSize: 13),
        filled: true,
        fillColor: p.inputBg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _EditableField {
  final nameCtrl = TextEditingController();
  final valueCtrl = TextEditingController();
  bool inline = true;

  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
  }
}
