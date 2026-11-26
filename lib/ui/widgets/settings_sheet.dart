import 'package:flutter/material.dart';

import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';

/// Official Discord Mobile "Settings" screen (opened from the Gear icon in the "You" tab).
class DiscordSettingsScreen extends StatelessWidget {
  final BotClientController controller;

  const DiscordSettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final eco = controller.ecoSettings;
        final p = DiscordPalette(oled: eco.oledBlackMode);

        return Scaffold(
          backgroundColor: p.sidebarBg,
          appBar: AppBar(
            backgroundColor: p.sidebarBg,
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _groupLabel(p, 'Account Settings'),
              _settingsGroup(p, [
                ListTile(
                  leading: Icon(Icons.swap_horiz_rounded,
                      color: p.textSecondary),
                  title: Text('Switch Accounts',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  trailing:
                      Icon(Icons.chevron_right, color: p.textMuted, size: 20),
                  onTap: () => showSwitchAccountsSheet(context, controller),
                ),
              ]),
              const SizedBox(height: 20),
              _groupLabel(p, 'App Settings'),
              _settingsGroup(p, [
                // Official Discord Mobile Appearance: Dark vs Midnight (AMOLED)
                ListTile(
                  leading: Icon(Icons.dark_mode_outlined,
                      color: p.textSecondary),
                  title: Text('Appearance',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    eco.oledBlackMode ? 'Midnight' : 'Dark',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5),
                  ),
                  trailing: Switch(
                    value: eco.oledBlackMode,
                    onChanged: (v) => controller.updateEcoSettings(
                      eco.copyWith(oledBlackMode: v),
                    ),
                  ),
                ),
                Divider(height: 1, color: p.border),
                SwitchListTile(
                  secondary: Icon(Icons.bolt_outlined, color: p.textSecondary),
                  title: Text('Low Power Mode',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    'Suspend background socket when idle',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5),
                  ),
                  value: eco.ecoPowerSaving,
                  onChanged: (v) => controller.updateEcoSettings(
                    eco.copyWith(ecoPowerSaving: v),
                    reconnectGateway: true,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _groupLabel(p, 'Gateway Intents'),
              _settingsGroup(p, [
                SwitchListTile(
                  title: Text('Message Content Intent',
                      style: TextStyle(color: p.textPrimary, fontSize: 14.5)),
                  value: eco.enableMessageContentIntent,
                  onChanged: (v) => controller.updateEcoSettings(
                    eco.copyWith(enableMessageContentIntent: v),
                    reconnectGateway: true,
                  ),
                ),
                Divider(height: 1, color: p.border),
                SwitchListTile(
                  title: Text('Server Members Intent',
                      style: TextStyle(color: p.textPrimary, fontSize: 14.5)),
                  value: eco.enableMembersIntent,
                  onChanged: (v) => controller.updateEcoSettings(
                    eco.copyWith(enableMembersIntent: v),
                    reconnectGateway: true,
                  ),
                ),
                Divider(height: 1, color: p.border),
                SwitchListTile(
                  title: Text('Presence Intent',
                      style: TextStyle(color: p.textPrimary, fontSize: 14.5)),
                  value: eco.enablePresenceIntent,
                  onChanged: (v) => controller.updateEcoSettings(
                    eco.copyWith(enablePresenceIntent: v),
                    reconnectGateway: true,
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _settingsGroup(p, [
                ListTile(
                  leading: const Icon(Icons.logout_rounded,
                      color: DiscordPalette.danger),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: DiscordPalette.danger,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await controller.logoutCurrentAccount();
                  },
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _groupLabel(DiscordPalette p, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: p.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _settingsGroup(DiscordPalette p, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: p.chatBg,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// Official Discord Mobile "Change Status" bottom sheet.
void showDiscordStatusSheet(
  BuildContext context,
  BotClientController controller,
) {
  final p = DiscordPalette(oled: controller.ecoSettings.oledBlackMode);
  final activityCtrl =
      TextEditingController(text: controller.botActivityName);
  String status = controller.botStatus;
  int activityType = controller.botActivityType;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Change Status',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: p.chatBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _statusTile(
                        p,
                        label: 'Online',
                        value: 'online',
                        current: status,
                        dotColor: DiscordPalette.green,
                        onTap: () => setModalState(() => status = 'online'),
                      ),
                      Divider(height: 1, color: p.border),
                      _statusTile(
                        p,
                        label: 'Idle',
                        value: 'idle',
                        current: status,
                        dotColor: DiscordPalette.yellow,
                        onTap: () => setModalState(() => status = 'idle'),
                      ),
                      Divider(height: 1, color: p.border),
                      _statusTile(
                        p,
                        label: 'Do Not Disturb',
                        value: 'dnd',
                        current: status,
                        dotColor: DiscordPalette.danger,
                        onTap: () => setModalState(() => status = 'dnd'),
                      ),
                      Divider(height: 1, color: p.border),
                      _statusTile(
                        p,
                        label: 'Invisible',
                        value: 'invisible',
                        current: status,
                        dotColor: DiscordPalette.greyStatus,
                        onTap: () => setModalState(() => status = 'invisible'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.chatBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      DropdownButton<int>(
                        value: activityType,
                        underline: const SizedBox.shrink(),
                        dropdownColor: p.cardBg,
                        style: TextStyle(color: p.textPrimary, fontSize: 13.5),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Playing')),
                          DropdownMenuItem(value: 2, child: Text('Listening')),
                          DropdownMenuItem(value: 3, child: Text('Watching')),
                          DropdownMenuItem(value: 5, child: Text('Competing')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => activityType = v);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: activityCtrl,
                          style: TextStyle(color: p.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Set Activity Status...',
                            hintStyle:
                                TextStyle(color: p.textMuted, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DiscordPalette.blurple,
                    ),
                    onPressed: () {
                      controller.updateBotPresence(
                        status: status,
                        activityType: activityType,
                        activityName: activityCtrl.text,
                      );
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _statusTile(
  DiscordPalette p, {
  required String label,
  required String value,
  required String current,
  required Color dotColor,
  required VoidCallback onTap,
}) {
  final selected = current == value;
  return ListTile(
    onTap: onTap,
    leading: Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
    ),
    title: Text(label, style: TextStyle(color: p.textPrimary, fontSize: 15)),
    trailing: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_off,
      color: selected ? DiscordPalette.blurple : p.textMuted,
      size: 20,
    ),
  );
}

/// Official Discord Mobile "Switch Accounts" bottom sheet.
void showSwitchAccountsSheet(
  BuildContext context,
  BotClientController controller,
) {
  final p = DiscordPalette(oled: controller.ecoSettings.oledBlackMode);
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Switch Accounts',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: p.chatBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: controller.savedAccounts.map((acc) {
                    final active = acc.id == controller.activeAccount?.id;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            NetworkImage(acc.avatarUrl(size: 64)),
                      ),
                      title: Text(
                        acc.displayName,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(acc.username,
                          style: TextStyle(color: p.textMuted, fontSize: 12)),
                      trailing: active
                          ? const Icon(Icons.check_circle,
                              color: DiscordPalette.blurple, size: 20)
                          : null,
                      onTap: active
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                              await controller.loginWithToken(
                                acc.token,
                                silentAccountSwitch: true,
                              );
                            },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    await controller.logoutCurrentAccount();
                  },
                  child: const Text('Add an Account'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
