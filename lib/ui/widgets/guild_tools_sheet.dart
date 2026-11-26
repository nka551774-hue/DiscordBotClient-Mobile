import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';

/// Authentic Discord Mobile Channel Details & Member List Sheet
/// (opened by tapping the channel header or Members icon in a chat).
class ChannelMembersSheet extends StatefulWidget {
  final BotClientController controller;
  final DiscordPalette palette;
  final VoidCallback onOpenPins;

  const ChannelMembersSheet({
    super.key,
    required this.controller,
    required this.palette,
    required this.onOpenPins,
  });

  @override
  State<ChannelMembersSheet> createState() => _ChannelMembersSheetState();
}

class _ChannelMembersSheetState extends State<ChannelMembersSheet> {
  List<DiscordMember> _members = const [];
  bool _loading = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers({String? query}) async {
    final guild = widget.controller.selectedGuild;
    final rest = widget.controller.rest;
    if (guild == null || rest == null) return;

    setState(() => _loading = true);
    try {
      final res = (query != null && query.trim().isNotEmpty)
          ? await rest.searchGuildMembers(guild.id, query.trim())
          : await rest.getGuildMembers(guild.id, limit: 100);
      if (mounted) setState(() => _members = res);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showChannelEditDialog(DiscordChannel channel) async {
    final nameCtrl = TextEditingController(text: channel.name);
    final topicCtrl = TextEditingController(text: channel.topic ?? '');
    final p = widget.palette;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.cardBg,
        title: const Text('Channel Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Channel Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: topicCtrl,
              decoration: const InputDecoration(labelText: 'Channel Topic'),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: DiscordPalette.danger),
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await widget.controller.rest?.deleteChannel(channel.id);
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.controller.rest?.modifyChannel(
                channel.id,
                name: nameCtrl.text.trim(),
                topic: topicCtrl.text.trim(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final channel = widget.controller.selectedChannel;
    final guild = widget.controller.selectedGuild;
    final perms = widget.controller.currentChannelPermissions();
    final canManageChannels =
        DiscordPermissions.has(perms, DiscordPermissions.manageChannels);
    final canKick =
        DiscordPermissions.has(perms, DiscordPermissions.kickMembers);
    final canBan =
        DiscordPermissions.has(perms, DiscordPermissions.banMembers);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
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
            const SizedBox(height: 16),

            // Channel Header (1:1 Discord Mobile)
            if (channel != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    channel.isDm ? Icons.alternate_email : Icons.tag_rounded,
                    color: p.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      channel.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (channel.topic != null && channel.topic!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  channel.topic!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textSecondary, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),

              // Discord Mobile Circular Action Row: Pins / Invite / Settings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleAction(
                    p,
                    icon: Icons.push_pin_rounded,
                    label: 'Pins',
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenPins();
                    },
                  ),
                  if (!channel.isDm)
                    _circleAction(
                      p,
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Invite',
                      onTap: () async {
                        try {
                          final url = await widget.controller.rest!
                              .createChannelInvite(channel.id);
                          await Clipboard.setData(ClipboardData(text: url));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invite copied: $url')),
                            );
                          }
                        } catch (_) {}
                      },
                    ),
                  if (!channel.isDm && canManageChannels)
                    _circleAction(
                      p,
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      onTap: () => _showChannelEditDialog(channel),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: p.border, height: 1),
              const SizedBox(height: 14),
            ],

            // DM Recipient or Server Member List
            if (channel != null && channel.isDm) ...[
              if (channel.dmRecipient != null)
                _memberRow(
                  p,
                  user: channel.dmRecipient!,
                  displayName: channel.dmRecipient!.displayName,
                  canKick: false,
                  canBan: false,
                  guildId: null,
                ),
            ] else if (guild != null) ...[
              TextField(
                controller: _searchCtrl,
                onSubmitted: (q) => _loadMembers(query: q),
                style: TextStyle(color: p.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search members',
                  hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 20, color: p.textMuted),
                  filled: true,
                  fillColor: p.elevatedBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'MEMBERS${guild.memberCount != null ? ' — ${guild.memberCount}' : ''}',
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._members.map((m) => _memberRow(
                      p,
                      user: m.user,
                      displayName: m.effectiveName,
                      canKick: canKick,
                      canBan: canBan,
                      guildId: guild.id,
                    )),
            ],
          ],
        );
      },
    );
  }

  Widget _circleAction(
    DiscordPalette p, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: p.inputBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: p.textPrimary, size: 21),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberRow(
    DiscordPalette p, {
    required DiscordUser user,
    required String displayName,
    required bool canKick,
    required bool canBan,
    required String? guildId,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(user.avatarUrl(size: 64)),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (user.bot) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: DiscordPalette.blurple,
                borderRadius: BorderRadius.circular(4),
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
          ],
        ],
      ),
      subtitle: Text(
        user.username,
        style: TextStyle(color: p.textMuted, fontSize: 12.5),
      ),
      onTap: () => _showUserProfileSheet(
        p,
        user: user,
        displayName: displayName,
        canKick: canKick,
        canBan: canBan,
        guildId: guildId,
      ),
    );
  }

  void _showUserProfileSheet(
    DiscordPalette p, {
    required DiscordUser user,
    required String displayName,
    required bool canKick,
    required bool canBan,
    required String? guildId,
  }) {
    final created = snowflakeCreatedAt(user.id);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final createdStr =
        '${months[created.month - 1]} ${created.day}, ${created.year}';

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(user.avatarUrl(size: 128)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          user.username,
                          style:
                              TextStyle(color: p.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.elevatedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Since',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdStr,
                      style: TextStyle(color: p.textPrimary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (user.id != widget.controller.activeAccount?.id)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: DiscordPalette.blurple,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                          await widget.controller.openDmWithUser(user.id);
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                        label: const Text('Message'),
                      ),
                    ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: user.id));
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Copy User ID'),
                  ),
                ],
              ),
              if (guildId != null && (canKick || canBan)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (canKick)
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: DiscordPalette.danger),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await widget.controller.rest
                              ?.kickMember(guildId, user.id);
                          _loadMembers();
                        },
                        child: const Text('Kick'),
                      ),
                    if (canBan)
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: DiscordPalette.danger),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await widget.controller.rest
                              ?.banMember(guildId, user.id);
                          _loadMembers();
                        },
                        child: const Text('Ban'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
