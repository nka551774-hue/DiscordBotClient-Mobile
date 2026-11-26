import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'user_profile_sheet.dart';
import 'vencord_sheets.dart';

/// Authentic Discord Mobile Right Side-Panel / Drawer:
/// - Channel Header + Topic
/// - Circular Quick Actions: 釘選 / 討論串 / 邀請 / 設定
/// - Member List grouped by Hoisted Roles (with Role Colors!), matching Discord & VencordDBCPlugin!
class ChannelDetailsSidePanel extends StatefulWidget {
  final BotClientController controller;
  final DiscordPalette palette;
  final VoidCallback onOpenPins;
  final void Function(String threadChannelId)? onSelectThread;
  final VoidCallback? onClosePanel;
  final VoidCallback? onNavigateToDm;

  const ChannelDetailsSidePanel({
    super.key,
    required this.controller,
    required this.palette,
    required this.onOpenPins,
    this.onSelectThread,
    this.onClosePanel,
    this.onNavigateToDm,
  });

  @override
  State<ChannelDetailsSidePanel> createState() =>
      _ChannelDetailsSidePanelState();
}

class _RoleGroupBucket {
  final String id;
  final String title;
  final int position;
  final int? color;
  final List<DiscordMember> members = <DiscordMember>[];

  _RoleGroupBucket({
    required this.id,
    required this.title,
    required this.position,
    this.color,
  });
}

class _ChannelDetailsSidePanelState extends State<ChannelDetailsSidePanel> {
  List<DiscordMember> _members = const [];
  bool _loading = false;
  String? _loadedGuildId;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ensureMembersLoaded();
  }

  @override
  void didUpdateWidget(covariant ChannelDetailsSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.selectedGuildId != _loadedGuildId) {
      _ensureMembersLoaded();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureMembersLoaded({String? query}) async {
    if (!widget.controller.vencord
        .getSetting<bool>('BotClient', 'showMemberList', true)) {
      return;
    }
    final guild = widget.controller.selectedGuild;
    final rest = widget.controller.rest;
    if (guild == null || rest == null) return;

    _loadedGuildId = guild.id;
    // Seed immediately from cachedMembers so list isn't empty even without GUILD_MEMBERS intent!
    if ((query == null || query.isEmpty) && guild.cachedMembers.isNotEmpty) {
      _members = guild.cachedMembers.values.toList();
    }

    setState(() => _loading = true);
    try {
      final res = (query != null && query.trim().isNotEmpty)
          ? await rest.searchGuildMembers(guild.id, query.trim())
          : await rest.getGuildMembers(guild.id, limit: 100);
      if (mounted && res.isNotEmpty) {
        setState(() => _members = res);
      }
    } catch (_) {
      // Keep cachedMembers fallback gracefully
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_RoleGroupBucket> _groupMembersByHoistedRole(
    DiscordGuild guild,
    List<DiscordMember> members,
  ) {
    final buckets = <String, _RoleGroupBucket>{};
    final ungrouped = _RoleGroupBucket(
      id: 'members',
      title: '成員',
      position: -1,
    );

    for (final m in members) {
      final hoistId = m.resolveHoistRoleId(guild.roles);
      if (hoistId != null && guild.roles.containsKey(hoistId)) {
        final r = guild.roles[hoistId]!;
        final b = buckets.putIfAbsent(
          r.id,
          () => _RoleGroupBucket(
            id: r.id,
            title: r.name,
            position: r.position,
            color: r.color != 0 ? r.color : null,
          ),
        );
        b.members.add(m);
      } else {
        ungrouped.members.add(m);
      }
    }

    final sorted = buckets.values.toList()
      ..sort((a, b) => b.position.compareTo(a.position));
    for (final b in sorted) {
      b.members.sort((a, b2) =>
          a.effectiveName.toLowerCase().compareTo(b2.effectiveName.toLowerCase()));
    }
    if (ungrouped.members.isNotEmpty) {
      ungrouped.members.sort((a, b2) =>
          a.effectiveName.toLowerCase().compareTo(b2.effectiveName.toLowerCase()));
      sorted.add(ungrouped);
    }
    return sorted;
  }

  void _showThreadsSheet(DiscordChannel parentChannel, DiscordPalette p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, sCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '討論串',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(height: 1, color: p.border),
            Expanded(
              child: FutureBuilder<List<DiscordChannel>>(
                future: widget.controller.fetchForumThreads(parentChannel),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final threads = snap.data ?? const [];
                  if (threads.isEmpty) {
                    return Center(
                      child: Text('此頻道尚無討論串',
                          style: TextStyle(color: p.textMuted)),
                    );
                  }
                  return ListView.builder(
                    controller: sCtrl,
                    itemCount: threads.length,
                    itemBuilder: (_, i) {
                      final t = threads[i];
                      return ListTile(
                        leading: Icon(Icons.subdirectory_arrow_right_rounded,
                            color: p.textMuted),
                        title: Text(t.name,
                            style: TextStyle(color: p.textPrimary)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          widget.onSelectThread?.call(t.id);
                        },
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

  Future<void> _showChannelEditDialog(DiscordChannel channel) async {
    final nameCtrl = TextEditingController(text: channel.name);
    final topicCtrl = TextEditingController(text: channel.topic ?? '');
    final p = widget.palette;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.cardBg,
        title: const Text('頻道設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '頻道名稱'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: topicCtrl,
              decoration: const InputDecoration(labelText: '頻道主題'),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: DiscordPalette.danger),
            onPressed: () async {
              Navigator.of(ctx).pop();
              widget.onClosePanel?.call();
              await widget.controller.rest?.deleteChannel(channel.id);
            },
            child: const Text('刪除頻道'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
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
            child: const Text('儲存'),
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

    final groupedBuckets = (guild != null && _members.isNotEmpty)
        ? _groupMembersByHoistedRole(guild, _members)
        : const <_RoleGroupBucket>[];

    return Container(
      color: p.sidebarBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (channel != null) ...[
            Row(
              children: [
                Icon(
                  channel.isDm ? Icons.alternate_email : Icons.tag_rounded,
                  color: p.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    channel.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
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
                style: TextStyle(color: p.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),

            // Circular Discord Action Row: 釘選 / 討論串 / 邀請 / 設定 / Vencord 工具
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 14,
              runSpacing: 10,
              children: [
                _circleAction(
                  p,
                  icon: Icons.push_pin_rounded,
                  label: '釘選',
                  onTap: widget.onOpenPins,
                ),
                if (!channel.isDm && !channel.isThread)
                  _circleAction(
                    p,
                    icon: Icons.forum_outlined,
                    label: '討論串',
                    onTap: () => _showThreadsSheet(channel, p),
                  ),
                if (!channel.isDm)
                  _circleAction(
                    p,
                    icon: Icons.person_add_alt_1_rounded,
                    label: '邀請',
                    onTap: () async {
                      try {
                        final url = await widget.controller.rest!
                            .createChannelInvite(channel.id);
                        await Clipboard.setData(ClipboardData(text: url));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已複製邀請連結：$url')),
                          );
                        }
                      } catch (_) {}
                    },
                  ),
                if (!channel.isDm && canManageChannels)
                  _circleAction(
                    p,
                    icon: Icons.settings_rounded,
                    label: '設定',
                    onTap: () => _showChannelEditDialog(channel),
                  ),
                if (!channel.isDm &&
                    widget.controller.vencord
                        .isPluginEnabled('PermissionsViewer'))
                  _circleAction(
                    p,
                    icon: Icons.admin_panel_settings_outlined,
                    label: '權限',
                    onTap: () => showVencordPermissionsModal(
                      context,
                      palette: p,
                      title: '#${channel.name}',
                      permissions: perms,
                    ),
                  ),
                if (widget.controller.vencord.isPluginEnabled('ViewRaw'))
                  _circleAction(
                    p,
                    icon: Icons.code_rounded,
                    label: 'Raw',
                    onTap: () => showVencordRawModal(
                      context,
                      palette: p,
                      title: 'Channel',
                      data: channel.toJson(),
                      sortKeys: widget.controller.vencord
                          .getSetting<bool>('ViewRaw', 'sortKeys', true),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: p.border, height: 1),
            const SizedBox(height: 14),
          ],

          // DM Recipient or Categorized Guild Member List
          if (channel != null && channel.isDm) ...[
            if (channel.dmRecipient != null)
              _memberRow(
                p,
                user: channel.dmRecipient!,
                member: null,
                displayName: channel.dmRecipient!.displayName,
                roleColorInt: null,
                guildId: null,
              ),
          ] else if (guild != null) ...[
            if (!widget.controller.vencord
                .getSetting<bool>('BotClient', 'showMemberList', true))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    '已於 Vencord > BotClient 停用成員列表',
                    style: TextStyle(color: p.textMuted, fontSize: 13),
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _searchCtrl,
                onSubmitted: (q) => _ensureMembersLoaded(query: q),
                style: TextStyle(color: p.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜尋成員',
                  hintStyle: TextStyle(color: p.textMuted, fontSize: 13.5),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 19, color: p.textMuted),
                  filled: true,
                  fillColor: p.elevatedBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading && _members.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...groupedBuckets.expand((bucket) {
                  final colorHeader = widget.controller.vencord
                          .isPluginEnabled('RoleColorEverywhere') &&
                      widget.controller.vencord.getSetting<bool>(
                          'RoleColorEverywhere', 'roleHeaders', true) &&
                      bucket.color != null;
                  return [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Text(
                        '${bucket.title.toUpperCase()} — ${bucket.members.length}',
                        style: TextStyle(
                          color: colorHeader
                              ? Color(0xFF000000 | bucket.color!)
                              : p.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    ...bucket.members.map((m) => _memberRow(
                          p,
                          user: m.user,
                          member: m,
                          displayName: m.effectiveName,
                          roleColorInt: m.resolveColor(guild.roles),
                          guildId: guild.id,
                        )),
                  ];
                }),
            ],
          ],
        ],
      ),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.elevatedBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: p.textPrimary, size: 20),
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
    required DiscordMember? member,
    required String displayName,
    required int? roleColorInt,
    required String? guildId,
  }) {
    final nameColor =
        roleColorInt != null ? Color(0xFF000000 | roleColorInt) : p.textPrimary;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 17,
        backgroundImage: NetworkImage(
          member != null
              ? member.effectiveAvatarUrl(guildId, size: 64)
              : user.avatarUrl(size: 64),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: nameColor,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (user.bot) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
              decoration: BoxDecoration(
                color: DiscordPalette.blurple,
                borderRadius: BorderRadius.circular(3.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user.isVerifiedBot) ...[
                    const Icon(Icons.check_rounded,
                        size: 10, color: Colors.white),
                    const SizedBox(width: 1),
                  ],
                  const Text(
                    'APP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        user.username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: p.textMuted, fontSize: 12),
      ),
      onTap: () => showUserProfileSheet(
        context,
        controller: widget.controller,
        initialUser: user,
        initialMember: member,
        guildId: guildId,
        onNavigateToDm: () {
          widget.onClosePanel?.call();
          widget.onNavigateToDm?.call();
        },
      ),
    );
  }
}
