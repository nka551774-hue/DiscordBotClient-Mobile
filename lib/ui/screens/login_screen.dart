import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final BotClientController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tokenCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _tokenCtrl.text = data.text!.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);

    return Scaffold(
      backgroundColor: p.chatBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Badge
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5865F2), Color(0xFF3B44C4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: DiscordPalette.blurple.withAlpha(80),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'DiscordBotClient Mobile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '極致輕量 • 原生 120fps • OLED 超低耗能機器人客戶端',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  // Saved Accounts Quick Login
                  if (ctrl.savedAccounts.isNotEmpty) ...[
                    Text(
                      '快速登入已儲存的機器人',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...ctrl.savedAccounts.map((acc) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: p.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.border),
                          ),
                          child: ListTile(
                            onTap: ctrl.authenticating
                                ? null
                                : () => ctrl.loginWithToken(acc.token),
                            leading: CircleAvatar(
                              backgroundImage:
                                  NetworkImage(acc.avatarUrl(size: 64)),
                            ),
                            title: Text(
                              acc.displayName,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              acc.tag,
                              style:
                                  TextStyle(color: p.textMuted, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.close,
                                  size: 18, color: p.textMuted),
                              onPressed: () =>
                                  ctrl.removeSavedAccount(acc.id),
                            ),
                          ),
                        )),
                    const SizedBox(height: 14),
                  ],

                  // Token Input Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: p.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '使用 Bot Token 登入',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _tokenCtrl,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          style:
                              TextStyle(color: p.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '貼上您的 Discord Bot Token...',
                            hintStyle:
                                TextStyle(color: p.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: p.inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '貼上',
                                  onPressed: _pasteFromClipboard,
                                  icon: Icon(Icons.content_paste_rounded,
                                      size: 19, color: p.textSecondary),
                                ),
                                IconButton(
                                  tooltip: '顯示/隱藏',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 19,
                                    color: p.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (ctrl.authError != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: DiscordPalette.red.withAlpha(35),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: DiscordPalette.red.withAlpha(110)),
                            ),
                            child: Text(
                              ctrl.authError!,
                              style: const TextStyle(
                                color: Color(0xFFFF8A8C),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: DiscordPalette.blurple,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: ctrl.authenticating
                              ? null
                              : () => ctrl.loginWithToken(_tokenCtrl.text),
                          child: ctrl.authenticating
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '登入機器人',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Developer Portal Setup Hint
                  ExpansionTile(
                    collapsedIconColor: p.textMuted,
                    iconColor: p.textSecondary,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 6),
                    title: Text(
                      '💡 必讀：如何開啟 Message Content Intent？',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1. 前往 Discord Developer Portal 選擇您的應用程式。\n'
                              '2. 點選左側「Bot」分頁，往下捲動至 Privileged Gateway Intents。\n'
                              '3. 開啟「MESSAGE CONTENT INTENT」並儲存，機器人即可完整讀取所有頻道訊息！\n'
                              '4. Token 僅加密儲存於本機裝置，直連 Discord 官方 API v10，絕不經過任何第三方伺服器。',
                              style: TextStyle(
                                color: p.textMuted,
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                launchUrl(
                                  Uri.parse(
                                      'https://discord.com/developers/applications'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(Icons.open_in_new, size: 15),
                              label: const Text('開啟 Discord Developer Portal'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
