import 'package:flutter/material.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';

class SettingsAndEcoSheet extends StatefulWidget {
  final BotClientController controller;
  final DiscordPalette palette;

  const SettingsAndEcoSheet({
    super.key,
    required this.controller,
    required this.palette,
  });

  @override
  State<SettingsAndEcoSheet> createState() => _SettingsAndEcoSheetState();
}

class _SettingsAndEcoSheetState extends State<SettingsAndEcoSheet> {
  late String _status;
  late int _activityType;
  late TextEditingController _activityCtrl;

  @override
  void initState() {
    super.initState();
    _status = widget.controller.botStatus;
    _activityType = widget.controller.botActivityType;
    _activityCtrl =
        TextEditingController(text: widget.controller.botActivityName);
  }

  @override
  void dispose() {
    _activityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final eco = ctrl.ecoSettings;
        final p = DiscordPalette(oled: eco.oledBlackMode);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.94,
          builder: (context, scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '極致省電與機器人控制台',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),

                // 1. Eco & Performance Section
                _SectionCard(
                  palette: p,
                  title: '⚡ 極致省電與 120Hz 流暢度設定',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('OLED 純黑省電模式 (#000000)',
                          style: TextStyle(color: p.textPrimary, fontSize: 14)),
                      subtitle: Text('關閉手機螢幕黑色像素發光，大幅降低顯示器耗電',
                          style: TextStyle(color: p.textMuted, fontSize: 12)),
                      value: eco.oledBlackMode,
                      onChanged: (v) => ctrl.updateEcoSettings(
                        eco.copyWith(oledBlackMode: v),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('智慧極致省電引擎 (Eco Mode)',
                          style: TextStyle(color: p.textPrimary, fontSize: 14)),
                      subtitle: Text(
                          '過濾高頻狀態封包、限制動態貼圖與記憶體快取上限 (35MB)、背景自動休眠 WebSocket',
                          style: TextStyle(color: p.textMuted, fontSize: 12)),
                      value: eco.ecoPowerSaving,
                      onChanged: (v) => ctrl.updateEcoSettings(
                        eco.copyWith(ecoPowerSaving: v),
                        reconnectGateway: true,
                      ),
                    ),
                    if (eco.ecoPowerSaving)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '背景自動休眠延遲：${eco.backgroundSuspendSeconds} 秒',
                                style: TextStyle(
                                    color: p.textSecondary, fontSize: 13),
                              ),
                            ),
                            Slider(
                              value: eco.backgroundSuspendSeconds.toDouble(),
                              min: 10,
                              max: 90,
                              divisions: 8,
                              onChanged: (v) => ctrl.updateEcoSettings(
                                eco.copyWith(
                                    backgroundSuspendSeconds: v.round()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('靜音輸入 (不發送 Typing 封包)',
                          style: TextStyle(color: p.textPrimary, fontSize: 14)),
                      subtitle: Text('打字時不呼叫 /typing API，減少背景網路喚醒',
                          style: TextStyle(color: p.textMuted, fontSize: 12)),
                      value: eco.silentTyping,
                      onChanged: (v) => ctrl.updateEcoSettings(
                        eco.copyWith(silentTyping: v),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('顯示即時連線延遲與事件計數 HUD',
                          style: TextStyle(color: p.textPrimary, fontSize: 14)),
                      value: eco.showPerformanceHud,
                      onChanged: (v) => ctrl.updateEcoSettings(
                        eco.copyWith(showPerformanceHud: v),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ctrl.clearMemoryCaches();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已釋放圖片與歷史訊息記憶體快取')),
                          );
                        },
                        icon: const Icon(Icons.cleaning_services_outlined,
                            size: 16),
                        label: const Text('立即釋放記憶體快取'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Gateway Intents Section
                _SectionCard(
                  palette: p,
                  title: '🛰️ Gateway Intents (需在 Developer Portal 啟用)',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('MESSAGE_CONTENT (讀取訊息內文)',
                          style: TextStyle(color: p.textPrimary, fontSize: 14)),
                      subtitle: Text('必開！若未開啟將只能看到機器人自己或被提及的訊息',
                          style: TextStyle(color: p.textMuted, fontSize: 12)),
                      value: eco.enableMessageContentIntent,
                      onChanged: (v) => ctrl.updateEcoSettings(
                        eco.copyWith(enableMessageContentIntent: v),
                        reconnectGateway: true,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('GUILD_MEMBERS (完整成員名單)',
                          style: TextStyle(color: p.textPrimary, fontSize: 14)),
                      value: eco.enableMembersIntent,
                      onChanged: (v) => ctrl.updateEcoSettings(
                        eco.copyWith(enableMembersIntent: v),
                        reconnectGateway: true,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('GUILD_PRESENCES (成員上線狀態 - 較耗電)',
                          style: TextStyle(color: p.textPrimary, fontSize: 14)),
                      subtitle: Text('僅在關閉 Eco 省電模式時生效',
                          style: TextStyle(color: p.textMuted, fontSize: 12)),
                      value: eco.enablePresenceIntent,
                      onChanged: (v) => ctrl.updateEcoSettings(
                        eco.copyWith(enablePresenceIntent: v),
                        reconnectGateway: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. Bot Presence & Status Controller
                _SectionCard(
                  palette: p,
                  title: '🤖 機器人線上狀態 (Presence)',
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        _statusChip('online', '線上', DiscordPalette.green, p),
                        _statusChip('idle', '閒置', DiscordPalette.yellow, p),
                        _statusChip('dnd', '請勿打擾', DiscordPalette.red, p),
                        _statusChip(
                            'invisible', '隱身', DiscordPalette.greyStatus, p),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        DropdownButton<int>(
                          value: _activityType,
                          dropdownColor: p.cardBg,
                          style: TextStyle(color: p.textPrimary, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('正在玩')),
                            DropdownMenuItem(value: 2, child: Text('正在聽')),
                            DropdownMenuItem(value: 3, child: Text('正在看')),
                            DropdownMenuItem(value: 5, child: Text('正在競爭')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _activityType = v);
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _activityCtrl,
                            style:
                                TextStyle(color: p.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '自訂機器人活動文字...',
                              hintStyle:
                                  TextStyle(color: p.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: p.inputBg,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: DiscordPalette.blurple,
                        ),
                        onPressed: () {
                          ctrl.updateBotPresence(
                            status: _status,
                            activityType: _activityType,
                            activityName: _activityCtrl.text,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已即時更新機器人狀態')),
                          );
                        },
                        child: const Text('更新機器人狀態'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 4. Multi-Bot Account Switcher
                _SectionCard(
                  palette: p,
                  title: '🔑 已儲存的機器人帳號',
                  children: [
                    ...ctrl.savedAccounts.map((acc) {
                      final isCurrent = acc.id == ctrl.activeAccount?.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage:
                              NetworkImage(acc.avatarUrl(size: 64)),
                        ),
                        title: Text(
                          acc.displayName,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${acc.tag} • ID: ${acc.id}',
                          style: TextStyle(color: p.textMuted, fontSize: 12),
                        ),
                        trailing: isCurrent
                            ? const Chip(
                                label: Text('使用中',
                                    style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              )
                            : TextButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await ctrl.loginWithToken(
                                    acc.token,
                                    silentAccountSwitch: true,
                                  );
                                },
                                child: const Text('切換'),
                              ),
                      );
                    }),
                    const Divider(),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DiscordPalette.red,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await ctrl.logoutCurrentAccount();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('登出 / 切換其他 Bot Token'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statusChip(
    String value,
    String label,
    Color dotColor,
    DiscordPalette p,
  ) {
    final selected = _status == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _status = value),
      avatar: CircleAvatar(radius: 5, backgroundColor: dotColor),
      label: Text(label),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final DiscordPalette palette;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.palette,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
