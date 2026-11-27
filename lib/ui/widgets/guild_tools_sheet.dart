import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'discord_icons.dart';
import 'media_viewer.dart';
import 'member_moderation.dart';
import 'user_profile_sheet.dart';
import 'vencord_sheets.dart';
import '../../l10n/strings.dart';

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
  /// Shown as the official bottom-sheet details page (adds a drag handle).
  final bool asSheet;

  const ChannelDetailsSidePanel({
    super.key,
    required this.controller,
    required this.palette,
    required this.onOpenPins,
    this.onSelectThread,
    this.onClosePanel,
    this.onNavigateToDm,
    this.asSheet = false,
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
  String _filter = '';
  Future<List<DiscordMessage>>? _pinsFuture;
  String? _pinsFor;

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
    final ctrl = widget.controller;
    final splitByPresence = ctrl.hasPresenceData;
    final buckets = <String, _RoleGroupBucket>{};
    final ungrouped = _RoleGroupBucket(
      id: 'members',
      title: splitByPresence ? tr('線上') : tr('成員'),
      position: -1,
    );
    final offline = _RoleGroupBucket(
      id: 'offline',
      title: tr('離線'),
      position: -2,
    );
    final selfId = ctrl.activeAccount?.id;

    for (final m in members) {
      final isOnline = m.user.id == selfId
          ? ctrl.botStatus != 'invisible'
          : ctrl.presenceStatusOf(m.user.id) != 'offline';
      if (splitByPresence && !isOnline) {
        offline.members.add(m);
        continue;
      }
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
    if (offline.members.isNotEmpty) {
      offline.members.sort((a, b2) =>
          a.effectiveName.toLowerCase().compareTo(b2.effectiveName.toLowerCase()));
      sorted.add(offline);
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
                tr('討論串'),
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
                      child: Text(tr('此頻道尚無討論串'),
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
        title: Text(tr('頻道設定')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: tr('頻道名稱')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: topicCtrl,
              decoration: InputDecoration(labelText: tr('頻道主題')),
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
            child: Text(tr('刪除頻道')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('取消')),
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
            child: Text(tr('儲存')),
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

    final q = _filter.trim().toLowerCase();
    final visibleMembers = q.isEmpty
        ? _members
        : _members
            .where((m) =>
                m.effectiveName.toLowerCase().contains(q) ||
                m.user.username.toLowerCase().contains(q))
            .toList();
    return ValueListenableBuilder<int>(
      valueListenable: widget.controller.presenceRevisionNotifier,
      builder: (context, _, __) => _buildPanel(context, p, channel, guild,
          perms, canManageChannels, visibleMembers),
    );
  }

  List<DiscordMessage> get _loadedMessages =>
      widget.controller.messagesNotifier.value;

  Widget _emptyTab(DiscordPalette p, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, fontSize: 13.5),
          ),
        ),
      );

  Widget _messagePreviewTile(DiscordPalette p, DiscordMessage m) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(m.author.avatarUrl(size: 64)),
        ),
        title: Text(
          m.authorDisplayName(widget.controller.selectedGuild),
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          m.content.isEmpty ? tr('[附件 / Embed]') : m.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.textSecondary, fontSize: 13.5),
        ),
      );

  /// Official "搜尋" button. shortcut: bots cannot use Discord's search API,
  /// so this searches the messages already loaded for this channel.
  void _showLocalSearch(DiscordPalette p) {
    String q = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final needle = q.trim().toLowerCase();
          final res = needle.isEmpty
              ? const <DiscordMessage>[]
              : _loadedMessages
                  .where((m) => m.content.toLowerCase().contains(needle))
                  .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            builder: (_, sc) => Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setM(() => q = v),
                    style: TextStyle(color: p.textPrimary),
                    decoration: InputDecoration(
                      hintText: tr('搜尋此頻道已載入的訊息'),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: p.textMuted),
                      filled: true,
                      fillColor: p.elevatedBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: needle.isNotEmpty && res.isEmpty
                        ? _emptyTab(p, tr('找不到符合的訊息'))
                        : ListView.builder(
                            controller: sc,
                            itemCount: res.length,
                            itemBuilder: (_, i) =>
                                _messagePreviewTile(p, res[i]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _membersTab(
    DiscordPalette p,
    DiscordChannel channel,
    DiscordGuild? guild,
    List<_RoleGroupBucket> groupedBuckets,
  ) {
    final ctrl = widget.controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (channel.isDm) ...[
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
          if (!ctrl.vencord.getSetting<bool>('BotClient', 'showMemberList', true))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  tr('已於 Vencord > BotClient 停用成員列表'),
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                ),
              ),
            )
          else ...[
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _filter = v),
              onSubmitted: (q) => _ensureMembersLoaded(query: q),
              style: TextStyle(color: p.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr('搜尋成員'),
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
            const SizedBox(height: 8),
            if (_loading && _members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...groupedBuckets.expand((bucket) {
                final colorHeader =
                    ctrl.vencord.isPluginEnabled('RoleColorEverywhere') &&
                        ctrl.vencord.getSetting<bool>(
                            'RoleColorEverywhere', 'roleHeaders', true) &&
                        bucket.color != null;
                return [
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Text(
                      '${bucket.title} — ${bucket.members.length}',
                      style: TextStyle(
                        color: colorHeader
                            ? Color(0xFF000000 | bucket.color!)
                            : p.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
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
    );
  }

  Widget _mediaTab(DiscordPalette p) {
    final imgs = [
      for (final m in _loadedMessages)
        for (final a in m.attachments)
          if (a.isImage) a,
    ];
    if (imgs.isEmpty) return _emptyTab(p, tr('已載入的訊息中沒有媒體'));
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: imgs.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => showDiscordMediaViewer(
          context,
          items: [
            for (final a in imgs)
              MediaViewerItem(a.previewUrl(maxWidth: 2048), originalUrl: a.url),
          ],
          initialIndex: i,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imgs[i].previewUrl(maxWidth: 240),
            fit: BoxFit.cover,
            cacheWidth: 240,
            errorBuilder: (_, __, ___) => Container(color: p.elevatedBg),
          ),
        ),
      ),
    );
  }

  Widget _pinsTab(DiscordPalette p, DiscordChannel channel) {
    final rest = widget.controller.rest;
    if (rest == null) return _emptyTab(p, tr('尚未連線'));
    if (_pinsFor != channel.id || _pinsFuture == null) {
      _pinsFor = channel.id;
      _pinsFuture = rest.getPinnedMessages(channel.id);
    }
    return FutureBuilder<List<DiscordMessage>>(
      future: _pinsFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final pins = snap.data ?? const <DiscordMessage>[];
        if (pins.isEmpty) return _emptyTab(p, tr('此頻道目前沒有任何釘選訊息'));
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: pins.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
          itemBuilder: (_, i) => _messagePreviewTile(p, pins[i]),
        );
      },
    );
  }

  Widget _linksTab(DiscordPalette p) {
    final re = RegExp(r'https?://[^\s<>)]+');
    final links = <String>[
      for (final m in _loadedMessages)
        for (final mt in re.allMatches(m.content)) mt.group(0)!,
    ];
    if (links.isEmpty) return _emptyTab(p, tr('已載入的訊息中沒有連結'));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: links.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
      itemBuilder: (_, i) => ListTile(
        leading: Icon(Icons.link_rounded, color: p.textSecondary),
        title: Text(
          links[i],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: const Color(0xFF00A8FC), fontSize: 13.5),
        ),
        onTap: () {
          final uri = Uri.tryParse(links[i]);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  Widget _filesTab(DiscordPalette p) {
    final files = [
      for (final m in _loadedMessages)
        for (final a in m.attachments)
          if (!a.isImage) a,
    ];
    if (files.isEmpty) return _emptyTab(p, tr('已載入的訊息中沒有檔案'));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: files.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
      itemBuilder: (_, i) => ListTile(
        leading: Icon(Icons.insert_drive_file_outlined,
            color: p.textSecondary),
        title: Text(
          files[i].filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.textPrimary, fontSize: 14),
        ),
        subtitle: Text(
          files[i].formattedSize,
          style: TextStyle(color: p.textMuted, fontSize: 12),
        ),
        onTap: () {
          final uri = Uri.tryParse(files[i].url);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  /// Official channel details page: icon, name, topic, 4 round actions,
  /// then 成員 / 媒體 / 釘選 / 連結 / 檔案 tabs.
  Widget _buildPanel(
    BuildContext context,
    DiscordPalette p,
    DiscordChannel? channel,
    DiscordGuild? guild,
    BigInt perms,
    bool canManageChannels,
    List<DiscordMember> visibleMembers,
  ) {
    if (channel == null) return Container(color: p.sidebarBg);
    final ctrl = widget.controller;
    final groupedBuckets = (guild != null && visibleMembers.isNotEmpty)
        ? _groupMembersByHoistedRole(guild, visibleMembers)
        : const <_RoleGroupBucket>[];
    final dmUser = channel.dmRecipient;
    final subtitle = (channel.topic != null && channel.topic!.isNotEmpty)
        ? channel.topic!
        : (guild?.name ?? dmUser?.username ?? '');

    final Widget headerIcon;
    if (channel.isDm && dmUser != null) {
      headerIcon = CircleAvatar(
        radius: 32,
        backgroundImage: NetworkImage(dmUser.avatarUrl(size: 128)),
      );
    } else {
      headerIcon = Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.elevatedBg, shape: BoxShape.circle),
        child: channel.isThread
            ? Icon(Icons.chat_bubble_outline_rounded,
                size: 28, color: p.textPrimary)
            : (channel.type == 5
                ? Icon(Icons.campaign_rounded, size: 32, color: p.textPrimary)
                : (channel.isVoice
                    ? Icon(Icons.volume_up_rounded,
                        size: 30, color: p.textPrimary)
                    : DiscordChannelHashIcon(
                        locked: false,
                        color: p.textPrimary,
                        size: 32,
                      ))),
      );
    }

    final tabs = [tr('成員'), tr('媒體'), tr('釘選'), tr('連結'), tr('檔案')];
    return DefaultTabController(
      length: tabs.length,
      child: Container(
        color: p.sidebarBg,
        child: Column(
          children: [
            if (widget.asSheet) ...[
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            const SizedBox(height: 16),
            headerIcon,
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                channel.isDm ? channel.displayTitle : channel.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 3, 24, 0),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleAction(
                    p,
                    icon: Icons.search_rounded,
                    label: tr('搜尋'),
                    onTap: () => _showLocalSearch(p),
                  ),
                  if (!channel.isDm && !channel.isThread)
                    _circleAction(
                      p,
                      icon: Icons.forum_outlined,
                      label: tr('討論串'),
                      onTap: () => _showThreadsSheet(channel, p),
                    ),
                  if (!channel.isDm)
                    _circleAction(
                      p,
                      icon: Icons.person_add_alt_1_rounded,
                      label: tr('邀請'),
                      onTap: () async {
                        try {
                          final url =
                              await ctrl.rest!.createChannelInvite(channel.id);
                          await Clipboard.setData(ClipboardData(text: url));
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text(trf('已複製邀請連結：{0}', [url]))),
                            );
                          }
                        } catch (_) {}
                      },
                    ),
                  if (!channel.isDm && canManageChannels)
                    _circleAction(
                      p,
                      icon: Icons.settings_rounded,
                      label: tr('設定'),
                      onTap: () => _showChannelEditDialog(channel),
                    ),
                  if (!channel.isDm &&
                      ctrl.vencord.isPluginEnabled('PermissionsViewer'))
                    _circleAction(
                      p,
                      icon: Icons.admin_panel_settings_outlined,
                      label: tr('權限'),
                      onTap: () => showVencordPermissionsModal(
                        context,
                        palette: p,
                        title: '#${channel.name}',
                        permissions: perms,
                      ),
                    ),
                  if (ctrl.vencord.isPluginEnabled('ViewRaw'))
                    _circleAction(
                      p,
                      icon: Icons.code_rounded,
                      label: 'Raw',
                      onTap: () => showVencordRawModal(
                        context,
                        palette: p,
                        title: 'Channel',
                        data: channel.toJson(),
                        sortKeys: ctrl.vencord
                            .getSetting<bool>('ViewRaw', 'sortKeys', true),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: p.textPrimary,
              unselectedLabelColor: p.textMuted,
              indicatorColor: DiscordPalette.blurple,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: p.border,
              labelStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              tabs: [for (final t in tabs) Tab(text: t, height: 40)],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _membersTab(p, channel, guild, groupedBuckets),
                  _mediaTab(p),
                  _pinsTab(p, channel),
                  _linksTab(p),
                  _filesTab(p),
                ],
              ),
            ),
          ],
        ),
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

    final ctrl = widget.controller;
    final acc = ctrl.activeAccount;
    final isSelf = acc != null && acc.id == user.id;
    final status = isSelf ? ctrl.botStatus : ctrl.presenceStatusOf(user.id);
    final showStatus = isSelf || ctrl.hasPresenceData;
    final isOffline =
        showStatus && (status == 'offline' || status == 'invisible');
    final activity = isSelf
        ? (ctrl.botActivityName.isNotEmpty ? ctrl.botActivityName : null)
        : ctrl.presenceActivityOf(user.id);

    return Opacity(
      opacity: isOffline && !isSelf ? 0.4 : 1.0,
      child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onLongPress: () {
        final g = guildId != null ? ctrl.findGuildById(guildId) : null;
        if (g == null) return;
        HapticFeedback.mediumImpact();
        showMemberActionsSheet(
          context,
          controller: ctrl,
          guild: g,
          user: user,
          member: member,
          p: p,
          onViewProfile: () => showUserProfileSheet(
            context,
            controller: ctrl,
            initialUser: user,
            initialMember: member,
            guildId: guildId,
            onNavigateToDm: () {
              widget.onClosePanel?.call();
              widget.onNavigateToDm?.call();
            },
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(
                    member != null
                        ? member.effectiveAvatarUrl(guildId, size: 64)
                        : user.avatarUrl(size: 64),
                  ),
                ),
                if (showStatus && !isOffline)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: DiscordStatusBadge(
                      status: status,
                      size: 12,
                      borderColor: p.sidebarBg,
                      borderWidth: 2.5,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
            Flexible(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: nameColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (user.bot) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
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
                  if (activity != null && activity.isNotEmpty)
                    Text(
                      activity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textMuted, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
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
      ),
    );
  }
}
