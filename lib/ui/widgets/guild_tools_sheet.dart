import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';

class GuildToolsSheet extends StatefulWidget {
  final BotClientController controller;
  final DiscordPalette palette;

  const GuildToolsSheet({
    super.key,
    required this.controller,
    required this.palette,
  });

  @override
  State<GuildToolsSheet> createState() => _GuildToolsSheetState();
}

class _GuildToolsSheetState extends State<GuildToolsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<DiscordMember> _members = const [];
  bool _loadingMembers = false;
  String? _membersError;
  final _memberSearchCtrl = TextEditingController();

  List<AuditLogEntry> _auditLogs = const [];
  bool _loadingAudit = false;

  final _newChannelCtrl = TextEditingController();
  int _newChannelType = 0;

  String _invitePermPreset = 'admin';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _fetchMembers();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _memberSearchCtrl.dispose();
    _newChannelCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers({String? query}) async {
    final guild = widget.controller.selectedGuild;
    final rest = widget.controller.rest;
    if (guild == null || rest == null) return;

    setState(() {
      _loadingMembers = true;
      _membersError = null;
    });

    try {
      final list = (query != null && query.trim().isNotEmpty)
          ? await rest.searchGuildMembers(guild.id, query.trim())
          : await rest.getGuildMembers(guild.id, limit: 80);
      if (mounted) {
        setState(() => _members = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _membersError = '需要開啟 Server Members Intent 或搜尋特定成員名稱才能列出完整清單。';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMembers = false);
      }
    }
  }

  Future<void> _fetchAuditLogs() async {
    final guild = widget.controller.selectedGuild;
    final rest = widget.controller.rest;
    if (guild == null || rest == null) return;
    setState(() => _loadingAudit = true);
    try {
      final logs = await rest.getGuildAuditLogs(guild.id);
      if (mounted) setState(() => _auditLogs = logs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('讀取審計日誌失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAudit = false);
    }
  }

  String _buildBotInviteUrl() {
    final appId = widget.controller.activeAccount?.applicationId ??
        widget.controller.activeAccount?.id ??
        '';
    String perms = '8'; // Administrator
    if (_invitePermPreset == 'mod') {
      perms = '1099511627774';
    } else if (_invitePermPreset == 'basic') {
      perms = '274878221376';
    }
    return 'https://discord.com/oauth2/authorize?client_id=$appId&permissions=$perms&scope=bot%20applications.commands';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final guild = widget.controller.selectedGuild;
    final channel = widget.controller.selectedChannel;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TabBar(
              controller: _tabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: p.textMuted,
              indicatorColor: DiscordPalette.blurple,
              tabs: const [
                Tab(text: '成員管理'),
                Tab(text: '頻道與日誌'),
                Tab(text: '邀請機器人'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // TAB 1: Members
                  guild == null
                      ? Center(
                          child: Text('目前位於私訊模式',
                              style: TextStyle(color: p.textMuted)))
                      : ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(14),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _memberSearchCtrl,
                                    style: TextStyle(
                                        color: p.textPrimary, fontSize: 14),
                                    onSubmitted: (q) => _fetchMembers(query: q),
                                    decoration: InputDecoration(
                                      hintText: '搜尋成員暱稱或名稱...',
                                      hintStyle: TextStyle(
                                          color: p.textMuted, fontSize: 13),
                                      filled: true,
                                      fillColor: p.inputBg,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _fetchMembers(
                                      query: _memberSearchCtrl.text),
                                  icon: const Icon(Icons.search),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_loadingMembers)
                              const Center(
                                  child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ))
                            else if (_membersError != null && _members.isEmpty)
                              Text(_membersError!,
                                  style: TextStyle(
                                      color: p.textSecondary, fontSize: 13))
                            else
                              ..._members.map((m) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 17,
                                      backgroundImage: NetworkImage(
                                          m.user.avatarUrl(size: 64)),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            m.effectiveName,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: p.textPrimary,
                                                fontSize: 14),
                                          ),
                                        ),
                                        if (m.user.bot) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: DiscordPalette.blurple,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text('BOT',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text('ID: ${m.user.id}',
                                        style: TextStyle(
                                            color: p.textMuted, fontSize: 11)),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (action) async {
                                        if (action == 'dm') {
                                          Navigator.of(context).pop();
                                          await widget.controller
                                              .openDmWithUser(m.user.id);
                                        } else if (action == 'copy') {
                                          Clipboard.setData(
                                              ClipboardData(text: m.user.id));
                                        } else if (action == 'kick') {
                                          await widget.controller.rest
                                              ?.kickMember(guild.id, m.user.id);
                                          _fetchMembers();
                                        } else if (action == 'ban') {
                                          await widget.controller.rest
                                              ?.banMember(guild.id, m.user.id);
                                          _fetchMembers();
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'dm', child: Text('發送私訊')),
                                        PopupMenuItem(
                                            value: 'copy',
                                            child: Text('複製 User ID')),
                                        PopupMenuItem(
                                            value: 'kick',
                                            child: Text('踢出伺服器')),
                                        PopupMenuItem(
                                            value: 'ban', child: Text('封鎖成員')),
                                      ],
                                    ),
                                  )),
                          ],
                        ),

                  // TAB 2: Channel & Audit Logs
                  guild == null
                      ? Center(
                          child: Text('請先選擇伺服器以管理頻道',
                              style: TextStyle(color: p.textMuted)))
                      : ListView(
                          padding: const EdgeInsets.all(14),
                          children: [
                            if (channel != null && !channel.isDm) ...[
                              Text('目前頻道：#${channel.name}',
                                  style: TextStyle(
                                      color: p.textPrimary,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () async {
                                      try {
                                        final url = await widget
                                            .controller.rest!
                                            .createChannelInvite(channel.id);
                                        await Clipboard.setData(
                                            ClipboardData(text: url));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('已建立並複製邀請連結：$url')),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('建立邀請失敗：$e')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.link_rounded,
                                        size: 16),
                                    label: const Text('產生頻道邀請連結'),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: DiscordPalette.red),
                                    onPressed: () async {
                                      try {
                                        await widget.controller.rest!
                                            .deleteChannel(channel.id);
                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('刪除頻道失敗：$e')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16),
                                    label: const Text('刪除此頻道'),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                            ],
                            Text('新增伺服器頻道',
                                style: TextStyle(
                                    color: p.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                DropdownButton<int>(
                                  value: _newChannelType,
                                  dropdownColor: p.cardBg,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 0, child: Text('# 文字')),
                                    DropdownMenuItem(
                                        value: 2, child: Text('🔊 語音')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _newChannelType = v);
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _newChannelCtrl,
                                    style: TextStyle(
                                        color: p.textPrimary, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: '新頻道名稱',
                                      hintStyle: TextStyle(
                                          color: p.textMuted, fontSize: 13),
                                      filled: true,
                                      fillColor: p.inputBg,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 9),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () async {
                                    final name = _newChannelCtrl.text.trim();
                                    if (name.isEmpty) return;
                                    try {
                                      final created = await widget
                                          .controller.rest!
                                          .createGuildChannel(
                                        guild.id,
                                        name: name,
                                        type: _newChannelType,
                                      );
                                      _newChannelCtrl.clear();
                                      Navigator.of(context).pop();
                                      await widget.controller
                                          .selectChannel(created.id);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('建立頻道失敗：$e')),
                                      );
                                    }
                                  },
                                  child: const Text('建立'),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Text('伺服器審計日誌 (Audit Logs)',
                                    style: TextStyle(
                                        color: p.textPrimary,
                                        fontWeight: FontWeight.w700)),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _fetchAuditLogs,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('載入'),
                                ),
                              ],
                            ),
                            if (_loadingAudit)
                              const Center(child: CircularProgressIndicator())
                            else
                              ..._auditLogs.map((entry) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(entry.actionLabel,
                                        style:
                                            TextStyle(color: p.textPrimary)),
                                    subtitle: Text(
                                      '執行者: ${entry.userId ?? '-'} • 目標: ${entry.targetId ?? '-'}${entry.reason != null ? '\n原因: ${entry.reason}' : ''}',
                                      style: TextStyle(
                                          color: p.textMuted, fontSize: 11),
                                    ),
                                  )),
                          ],
                        ),

                  // TAB 3: OAuth2 Bot Invite URL Generator
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '邀請此機器人加入其他伺服器',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '選擇權限組合即可自動產生 Discord 官方 OAuth2 邀請網址：',
                        style: TextStyle(color: p.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      RadioListTile<String>(
                        value: 'admin',
                        groupValue: _invitePermPreset,
                        onChanged: (v) =>
                            setState(() => _invitePermPreset = v!),
                        title: const Text('管理員完整權限 (Administrator)'),
                      ),
                      RadioListTile<String>(
                        value: 'mod',
                        groupValue: _invitePermPreset,
                        onChanged: (v) =>
                            setState(() => _invitePermPreset = v!),
                        title: const Text('版務管理與訊息權限'),
                      ),
                      RadioListTile<String>(
                        value: 'basic',
                        groupValue: _invitePermPreset,
                        onChanged: (v) =>
                            setState(() => _invitePermPreset = v!),
                        title: const Text('基本聊天、傳送檔案與 Embed'),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.border),
                        ),
                        child: SelectableText(
                          _buildBotInviteUrl(),
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: _buildBotInviteUrl()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已複製邀請連結')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('複製連結'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: DiscordPalette.blurple,
                              ),
                              onPressed: () {
                                launchUrl(
                                  Uri.parse(_buildBotInviteUrl()),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 16),
                              label: const Text('在瀏覽器開啟'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
