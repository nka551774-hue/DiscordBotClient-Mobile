import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';

int _topRolePosition(DiscordGuild guild, List<String> roleIds) {
  var top = 0;
  for (final id in roleIds) {
    final pos = guild.roles[id]?.position ?? 0;
    if (pos > top) top = pos;
  }
  return top;
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() call,
  String okText, {
  VoidCallback? onSuccess,
}) async {
  try {
    await call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okText)));
    onSuccess?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Official confirm dialog with optional audit-log reason.
/// Returns null when cancelled, otherwise the (possibly empty) reason.
Future<String?> _confirmWithReason(
  BuildContext context,
  DiscordPalette p, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  // shortcut: controller is not disposed (dialog exit animation may still read it).
  final reasonCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.cardBg,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: TextStyle(color: p.textSecondary, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: '原因（選填，會記錄於審核日誌）',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: DiscordPalette.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true ? reasonCtrl.text.trim() : null;
}

/// Timeout picker; Duration.zero means "remove timeout".
Future<Duration?> _pickTimeout(BuildContext context, DiscordPalette p) {
  const options = <(String, Duration)>[
    ('60 秒', Duration(seconds: 60)),
    ('5 分鐘', Duration(minutes: 5)),
    ('10 分鐘', Duration(minutes: 10)),
    ('1 小時', Duration(hours: 1)),
    ('1 天', Duration(days: 1)),
    ('1 週', Duration(days: 7)),
  ];
  return showModalBottomSheet<Duration>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '禁言時長',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: p.sidebarBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in options)
                    ListTile(
                      title: Text(o.$1, style: TextStyle(color: p.textPrimary)),
                      onTap: () => Navigator.of(ctx).pop(o.$2),
                    ),
                  Divider(height: 1, color: p.border),
                  ListTile(
                    leading: Icon(Icons.timer_off_outlined,
                        color: p.textPrimary),
                    title: Text('解除禁言',
                        style: TextStyle(color: p.textPrimary)),
                    onTap: () => Navigator.of(ctx).pop(Duration.zero),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Official member moderation rows (禁言 / 踢出 / 停權), evaluated with
/// guild-level permissions and role hierarchy like Discord does server-side.
/// [context] must outlive [menuCtx] (it is used for dialogs and snackbars).
List<Widget> memberModerationTiles({
  required BuildContext context,
  required BuildContext menuCtx,
  required BotClientController controller,
  required DiscordGuild guild,
  required DiscordUser user,
  DiscordMember? member,
  required DiscordPalette p,
  VoidCallback? onRemoved,
}) {
  final acc = controller.activeAccount;
  final rest = controller.rest;
  if (acc == null || rest == null) return const [];
  if (acc.id == user.id || guild.ownerId == user.id) return const [];

  final perms = DiscordPermissions.computeGuildPermissions(
    guild: guild,
    userId: acc.id,
    roleIds: guild.botRoleIds,
  );
  final targetRoles = member?.roleIds ??
      guild.cachedMembers[user.id]?.roleIds ??
      const <String>[];
  final outranks = guild.ownerId == acc.id ||
      _topRolePosition(guild, guild.botRoleIds) >
          _topRolePosition(guild, targetRoles);
  final name = member?.effectiveName ?? user.displayName;

  final tiles = <Widget>[];
  void add(
    IconData icon,
    String label,
    BigInt flag,
    Future<void> Function() action,
  ) {
    if (!DiscordPermissions.has(perms, flag)) return;
    final color = outranks ? DiscordPalette.danger : p.textMuted;
    tiles.add(Divider(height: 1, color: p.border));
    tiles.add(ListTile(
      enabled: outranks,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: outranks
          ? null
          : Text(
              '機器人的最高身分組必須高於對方',
              style: TextStyle(color: p.textMuted, fontSize: 12),
            ),
      onTap: () async {
        Navigator.of(menuCtx).pop();
        await action();
      },
    ));
  }

  add(Icons.timer_outlined, '禁言 $name', DiscordPermissions.moderateMembers,
      () async {
    final d = await _pickTimeout(context, p);
    if (d == null || !context.mounted) return;
    final clear = d == Duration.zero;
    await _run(
      context,
      () => rest.timeoutMember(
        guild.id,
        user.id,
        until: clear ? null : DateTime.now().add(d),
      ),
      clear ? '已解除 $name 的禁言' : '已禁言 $name',
    );
  });

  add(Icons.person_remove_outlined, '踢出 $name', DiscordPermissions.kickMembers,
      () async {
    final reason = await _confirmWithReason(
      context,
      p,
      title: '踢出 $name',
      body: '確定要將 $name 踢出「${guild.name}」嗎？對方可以透過邀請重新加入。',
      confirmLabel: '踢出',
    );
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      () => rest.kickMember(guild.id, user.id,
          reason: reason.isEmpty ? null : reason),
      '已將 $name 踢出伺服器',
      onSuccess: onRemoved,
    );
  });

  add(Icons.gavel_rounded, '停權 $name', DiscordPermissions.banMembers,
      () async {
    final reason = await _confirmWithReason(
      context,
      p,
      title: '停權 $name',
      body: '確定要將 $name 從「${guild.name}」停權嗎？對方將無法再加入，直到解除停權。',
      confirmLabel: '停權',
    );
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      () => rest.banMember(guild.id, user.id,
          reason: reason.isEmpty ? null : reason),
      '已將 $name 停權',
      onSuccess: onRemoved,
    );
  });

  return tiles;
}

/// Long-press on a member (official): quick profile / copy ID / moderation.
void showMemberActionsSheet(
  BuildContext context, {
  required BotClientController controller,
  required DiscordGuild guild,
  required DiscordUser user,
  DiscordMember? member,
  required DiscordPalette p,
  required VoidCallback onViewProfile,
}) {
  final name = member?.effectiveName ?? user.displayName;
  showModalBottomSheet<void>(
    context: context,
    builder: (menuCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  member != null
                      ? member.effectiveAvatarUrl(guild.id, size: 96)
                      : user.avatarUrl(size: 96),
                ),
              ),
              title: Text(
                name,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(user.username,
                  style: TextStyle(color: p.textMuted, fontSize: 12.5)),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: p.sidebarBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.person_outline_rounded,
                        color: p.textPrimary),
                    title: Text('檢視個人資料',
                        style: TextStyle(color: p.textPrimary)),
                    onTap: () {
                      Navigator.of(menuCtx).pop();
                      onViewProfile();
                    },
                  ),
                  Divider(height: 1, color: p.border),
                  ListTile(
                    leading: Icon(Icons.copy_rounded, color: p.textPrimary),
                    title: Text('複製使用者 ID',
                        style: TextStyle(color: p.textPrimary)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.id));
                      Navigator.of(menuCtx).pop();
                    },
                  ),
                  ...memberModerationTiles(
                    context: context,
                    menuCtx: menuCtx,
                    controller: controller,
                    guild: guild,
                    user: user,
                    member: member,
                    p: p,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
