import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'user_profile_sheet.dart';
import '../../l10n/strings.dart';

/// Opens the authentic Discord Mobile Voice Channel Sheet:
/// - When NOT connected to [channel]: displays the "Join Voice" preview sheet
///   with live connected participants, start-muted mic toggle, green "加入語音" CTA,
///   and a separate Text-in-Voice chat button.
/// - When connected to [channel]: displays the full Active Voice Room with
///   live Voice RTT ping, green speaking rings (Opcode 5), tappable participant profiles,
///   Discord Soundboard (音效板), and bottom Voice Control Dock.
Future<void> showVoiceChannelSheet(
  BuildContext context, {
  required BotClientController controller,
  required DiscordGuild guild,
  required DiscordChannel channel,
  required void Function(String channelId, String guildId) onOpenVoiceTextChat,
  VoidCallback? onNavigateToDm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _VoiceChannelSheetContent(
        controller: controller,
        initialGuild: guild,
        initialChannel: channel,
        onOpenVoiceTextChat: (chId, gId) {
          Navigator.of(ctx).pop();
          onOpenVoiceTextChat(chId, gId);
        },
        onNavigateToDm: () {
          Navigator.of(ctx).pop();
          onNavigateToDm?.call();
        },
      );
    },
  );
}

class _VoiceChannelSheetContent extends StatefulWidget {
  final BotClientController controller;
  final DiscordGuild initialGuild;
  final DiscordChannel initialChannel;
  final void Function(String channelId, String guildId) onOpenVoiceTextChat;
  final VoidCallback? onNavigateToDm;

  const _VoiceChannelSheetContent({
    required this.controller,
    required this.initialGuild,
    required this.initialChannel,
    required this.onOpenVoiceTextChat,
    this.onNavigateToDm,
  });

  @override
  State<_VoiceChannelSheetContent> createState() =>
      _VoiceChannelSheetContentState();
}

class _VoiceChannelSheetContentState extends State<_VoiceChannelSheetContent> {
  late bool _previewStartMuted;

  @override
  void initState() {
    super.initState();
    _previewStartMuted = widget.controller.selfMute;
  }

  Future<void> _copyChannelInvite(
    DiscordChannel ch,
    BotClientController ctrl,
  ) async {
    if (ctrl.rest == null) return;
    try {
      final url = await ctrl.rest!.createChannelInvite(ch.id);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf('已複製語音頻道邀請連結：{0}', [url]))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf('無法建立邀請連結：{0}', [e]))),
        );
      }
    }
  }

  void _openSoundboardModal(
    BuildContext context,
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SoundboardBottomSheet(
        controller: ctrl,
        palette: p,
        guild: guild,
        channel: channel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);
        final guild =
            ctrl.findGuildById(widget.initialGuild.id) ?? widget.initialGuild;
        final channel = ctrl.findChannelById(widget.initialChannel.id) ??
            widget.initialChannel;

        final isConnectedHere = ctrl.activeVoiceChannelId == channel.id &&
            ctrl.activeVoiceGuildId == guild.id;
        final isConnectedElsewhere =
            ctrl.activeVoiceChannelId != null && !isConnectedHere;
        final hasUnreadText = ctrl.unreadChannelIds.contains(channel.id);
        final participants = guild.voiceStatesForChannel(channel.id);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: isConnectedHere ? 0.94 : 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, scrollCtrl) => isConnectedHere
              ? _buildRoom(context, ctrl, p, guild, channel, participants,
                  scrollCtrl, hasUnreadText)
              : _buildLobby(context, ctrl, p, guild, channel, participants,
                  scrollCtrl,
                  isConnectedElsewhere: isConnectedElsewhere,
                  hasUnreadText: hasUnreadText),
        );
      },
    );
  }

  ({String name, String avatar, int? color, bool bot, bool verified}) _who(
    BotClientController ctrl,
    DiscordGuild guild,
    VoiceState vs, {
    int size = 128,
  }) {
    final acc = ctrl.activeAccount;
    final isSelfBot = acc != null && vs.userId == acc.id;
    final member = vs.member ?? guild.cachedMembers[vs.userId];
    final name = isSelfBot
        ? (member?.effectiveName ?? acc.displayName)
        : (member?.effectiveName ?? 'User ${vs.userId}');
    final avatar = isSelfBot
        ? acc.avatarUrl(size: size)
        : (member != null
            ? member.effectiveAvatarUrl(guild.id, size: size)
            : 'https://cdn.discordapp.com/embed/avatars/${((BigInt.tryParse(vs.userId) ?? BigInt.zero) >> 22).toInt().abs() % 6}.png');
    return (
      name: name,
      avatar: avatar,
      color: member?.resolveColor(guild.roles),
      bot: isSelfBot || (member?.user.bot ?? false),
      verified:
          isSelfBot ? acc.isVerifiedBot : (member?.user.isVerifiedBot ?? false),
    );
  }

  Widget _handle(Color color) => Center(
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _topCircle(
    IconData icon,
    VoidCallback onTap, {
    Color bg = const Color(0x40000000),
    Color fg = Colors.white,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }

  Widget _appTag(bool verified) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
        decoration: BoxDecoration(
          color: DiscordPalette.blurple,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (verified) ...[
              const Icon(Icons.check_rounded, size: 9, color: Colors.white),
              const SizedBox(width: 1),
            ],
            const Text(
              'APP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  /// Official lobby header art: up to four overlapping participant avatars.
  Widget _avatarCluster(
    List<String> urls,
    DiscordPalette p,
    DiscordChannel channel,
  ) {
    if (urls.isEmpty) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(color: p.cardBg, shape: BoxShape.circle),
        child: Icon(
          channel.isStageVoice
              ? Icons.podcasts_rounded
              : Icons.volume_up_rounded,
          size: 38,
          color: p.textSecondary,
        ),
      );
    }
    if (urls.length == 1) {
      return CircleAvatar(radius: 42, backgroundImage: NetworkImage(urls.first));
    }
    const positions = [
      Offset(0, 6),
      Offset(52, 0),
      Offset(6, 54),
      Offset(46, 44),
    ];
    const radii = [28.0, 19.0, 19.0, 26.0];
    final shown = urls.take(4).toList();
    return SizedBox(
      width: 102,
      height: 102,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: positions[i].dx,
              top: positions[i].dy,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration:
                    BoxDecoration(color: p.profileBg, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: radii[i],
                  backgroundImage: NetworkImage(shown[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lobby (not connected): official "Join Voice" preview sheet
  // ---------------------------------------------------------------------------
  Widget _buildLobby(
    BuildContext context,
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel,
    List<VoiceState> participants,
    ScrollController scrollCtrl, {
    required bool isConnectedElsewhere,
    required bool hasUnreadText,
  }) {
    final infos =
        participants.map((vs) => _who(ctrl, guild, vs, size: 96)).toList();
    final String subtitle;
    if (infos.isEmpty) {
      subtitle = tr('目前沒有人在語音頻道中');
    } else if (infos.length == 1) {
      subtitle = infos[0].name;
    } else if (infos.length == 2) {
      subtitle = '${infos[0].name}、${infos[1].name}';
    } else {
      subtitle =
          trf('{0}、{1} 和其他 {2} 人', [infos[0].name, infos[1].name, infos.length - 2]);
    }
    final streamers = participants.where((vs) => vs.selfStream).toList();

    return Container(
      decoration: BoxDecoration(
        color: p.profileBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 104),
              children: [
                _handle(p.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _topCircle(
                      Icons.keyboard_arrow_down_rounded,
                      () => Navigator.of(context).pop(),
                      bg: p.elevatedBg,
                      fg: p.textPrimary,
                    ),
                    const Spacer(),
                    _topCircle(
                      Icons.person_add_alt_1_rounded,
                      () => _copyChannelInvite(channel, ctrl),
                      bg: p.elevatedBg,
                      fg: p.textPrimary,
                    ),
                  ],
                ),
                Center(
                  child: _avatarCluster(
                    infos.map((i) => i.avatar).toList(),
                    p,
                    channel,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  channel.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  channel.userLimit > 0
                      ? '$subtitle • ${participants.length}/${channel.userLimit}'
                      : subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textMuted, fontSize: 13.5),
                ),
                if (streamers.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    trf('{0} 正在直播...', [_who(ctrl, guild, streamers.first).name]),
                    style: TextStyle(color: p.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tr('直播中'),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                if (infos.isNotEmpty) const SizedBox(height: 18),
                for (var i = 0; i < infos.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border, indent: 44),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => showUserProfileById(
                      context,
                      controller: ctrl,
                      userId: participants[i].userId,
                      guildId: guild.id,
                      onNavigateToDm: widget.onNavigateToDm,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(infos[i].avatar),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              infos[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (infos[i].bot) _appTag(infos[i].verified),
                          const Spacer(),
                          if (participants[i].isDeafened)
                            Icon(Icons.headset_off_rounded,
                                size: 17, color: p.textMuted)
                          else if (participants[i].isMuted)
                            Icon(Icons.mic_off_rounded,
                                size: 17, color: p.textMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _buildJoinPreviewBar(
                ctrl,
                p,
                guild,
                channel,
                isConnectedElsewhere: isConnectedElsewhere,
                hasUnreadText: hasUnreadText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinPreviewBar(
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel, {
    required bool isConnectedElsewhere,
    required bool hasUnreadText,
  }) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: p.bottomBarBg,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 16),
        ],
      ),
      child: Row(
        children: [
          // Enter muted / unmuted (official: white mic = will join unmuted)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _previewStartMuted = !_previewStartMuted);
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _previewStartMuted ? p.elevatedBg : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _previewStartMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: _previewStartMuted ? DiscordPalette.danger : Colors.black,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DiscordPalette.green,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ctrl.joinVoiceChannel(
                    guild.id,
                    channel.id,
                    startMuted: _previewStartMuted,
                  );
                },
                child: Text(
                  isConnectedElsewhere ? tr('切換至此語音頻道') : tr('加入語音'),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Preview Text-in-Voice without joining
          GestureDetector(
            onTap: () => widget.onOpenVoiceTextChat(channel.id, guild.id),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: p.elevatedBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: p.textPrimary,
                    size: 20,
                  ),
                ),
                if (hasUnreadText)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: DiscordPalette.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.bottomBarBg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // In-call room: gradient stage, top pill bar, participant tiles, floating dock
  // ---------------------------------------------------------------------------
  Widget _buildRoom(
    BuildContext context,
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel,
    List<VoiceState> participants,
    ScrollController scrollCtrl,
    bool hasUnreadText,
  ) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2F2E8C),
            Color(0xFF4B3A8E),
            Color(0xFF7A4F80),
            Color(0xFFB0735F),
          ],
          stops: [0.0, 0.45, 0.8, 1.0],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _handle(const Color(0x66FFFFFF)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  _topCircle(
                    Icons.keyboard_arrow_down_rounded,
                    () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () =>
                            _showCallDetails(context, ctrl, p, guild, channel),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0x40000000),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  channel.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 17, color: Color(0xCCFFFFFF)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _topCircle(
                    ctrl.selfDeaf
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    () {
                      HapticFeedback.selectionClick();
                      ctrl.toggleVoiceDeaf();
                    },
                  ),
                  const SizedBox(width: 8),
                  _topCircle(
                    Icons.person_add_alt_1_rounded,
                    () => _copyChannelInvite(channel, ctrl),
                  ),
                ],
              ),
            ),
            if (!ctrl.isVoiceConnected)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  tr('連線中...'),
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: participants.isEmpty
                  ? Center(
                      child: Text(
                        tr('等待其他人加入...'),
                        style: TextStyle(color: Color(0xCCFFFFFF)),
                      ),
                    )
                  : ValueListenableBuilder<Set<String>>(
                      valueListenable: ctrl.speakingUserIdsNotifier,
                      builder: (_, speakingIds, __) {
                        final single = participants.length == 1;
                        return Center(
                          child: GridView.builder(
                            controller: scrollCtrl,
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: single ? 1 : 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: single ? 1.5 : 1.07,
                            ),
                            itemCount: participants.length,
                            itemBuilder: (_, idx) {
                              final vs = participants[idx];
                              return _buildParticipantTile(
                                context: context,
                                ctrl: ctrl,
                                guild: guild,
                                vs: vs,
                                isSpeaking: speakingIds.contains(vs.userId),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: _buildActiveVoiceDock(
                context,
                ctrl,
                p,
                guild,
                channel,
                hasUnreadText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile({
    required BuildContext context,
    required BotClientController ctrl,
    required DiscordGuild guild,
    required VoiceState vs,
    required bool isSpeaking,
  }) {
    final who = _who(ctrl, guild, vs);
    return GestureDetector(
      onTap: () => showUserProfileById(
        context,
        controller: ctrl,
        userId: vs.userId,
        guildId: guild.id,
        onNavigateToDm: widget.onNavigateToDm,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: const Color(0x4D1E1F22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSpeaking ? DiscordPalette.green : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(who.avatar),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (vs.isDeafened || vs.isMuted)
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: const BoxDecoration(
                              color: Color(0x66000000),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              vs.isDeafened
                                  ? Icons.headset_off_rounded
                                  : Icons.mic_off_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            who.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (who.bot) _appTag(who.verified),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (vs.selfStream)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: DiscordPalette.danger,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tr('直播'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Tapping the call-name pill opens call details (official behaviour).
  void _showCallDetails(
    BuildContext context,
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(p.border),
              const SizedBox(height: 12),
              Text(
                channel.name,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                guild.name,
                style: TextStyle(color: p.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: p.sidebarBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<int?>(
                      valueListenable: ctrl.voicePingMsNotifier,
                      builder: (_, voicePingMs, __) {
                        final ms = voicePingMs ?? ctrl.pingMsNotifier.value;
                        return ListTile(
                          leading: const Icon(
                            Icons.signal_cellular_alt_rounded,
                            color: DiscordPalette.green,
                          ),
                          title: Text(
                            ctrl.isVoiceConnected
                                ? (ms != null ? trf('語音已連線 • {0} ms', [ms]) : tr('語音已連線'))
                                : tr('連線中...'),
                            style: TextStyle(color: p.textPrimary),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, color: p.border),
                    ListTile(
                      leading: Icon(Icons.music_note_rounded,
                          color: p.textPrimary),
                      title: Text(tr('音效板'),
                          style: TextStyle(color: p.textPrimary)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _openSoundboardModal(context, ctrl, p, guild, channel);
                      },
                    ),
                    Divider(height: 1, color: p.border),
                    ListTile(
                      leading: Icon(Icons.person_add_alt_1_rounded,
                          color: p.textPrimary),
                      title: Text(tr('邀請'),
                          style: TextStyle(color: p.textPrimary)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _copyChannelInvite(channel, ctrl);
                      },
                    ),
                    Divider(height: 1, color: p.border),
                    ListTile(
                      leading: const Icon(Icons.call_end_rounded,
                          color: DiscordPalette.danger),
                      title: Text(tr('中斷連線'),
                          style: TextStyle(color: DiscordPalette.danger)),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await ctrl.leaveVoiceChannel();
                        if (mounted) Navigator.of(this.context).pop();
                      },
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

  Widget _buildActiveVoiceDock(
    BuildContext context,
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel,
    bool hasUnreadText,
  ) {
    final muted = ctrl.selfMute;
    final deafened = ctrl.selfDeaf;
    const dockBtnBg = Color(0x33FFFFFF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC1E1F22),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _VoiceDockCircleButton(
            icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            activeWhite: false,
            backgroundColor: dockBtnBg,
            tooltip: muted ? tr('取消靜音') : tr('靜音'),
            onTap: () {
              HapticFeedback.selectionClick();
              ctrl.toggleVoiceMute();
            },
          ),
          _VoiceDockCircleButton(
            icon: deafened ? Icons.headset_off_rounded : Icons.headset_rounded,
            activeWhite: deafened,
            backgroundColor: dockBtnBg,
            tooltip: deafened ? tr('取消拒聽') : tr('拒聽'),
            onTap: () {
              HapticFeedback.selectionClick();
              ctrl.toggleVoiceDeaf();
            },
          ),
          _VoiceDockCircleButton(
            icon: Icons.chat_bubble_rounded,
            activeWhite: hasUnreadText,
            backgroundColor: dockBtnBg,
            tooltip: tr('文字聊天室'),
            onTap: () => widget.onOpenVoiceTextChat(channel.id, guild.id),
          ),
          _VoiceDockCircleButton(
            icon: Icons.rocket_launch_rounded,
            activeWhite: false,
            backgroundColor: dockBtnBg,
            tooltip: tr('活動與音效板'),
            onTap: () {
              HapticFeedback.selectionClick();
              _openSoundboardModal(context, ctrl, p, guild, channel);
            },
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await ctrl.leaveVoiceChannel();
              if (mounted) Navigator.of(context).pop();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: DiscordPalette.danger,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceDockCircleButton extends StatelessWidget {
  final IconData icon;
  final bool activeWhite;
  final Color backgroundColor;
  final String tooltip;
  final VoidCallback onTap;

  const _VoiceDockCircleButton({
    required this.icon,
    required this.activeWhite,
    required this.backgroundColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: activeWhite ? Colors.white : backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: activeWhite ? Colors.black : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Authentic Discord Mobile Soundboard Sheet (音效板)
class _SoundboardBottomSheet extends StatefulWidget {
  final BotClientController controller;
  final DiscordPalette palette;
  final DiscordGuild guild;
  final DiscordChannel channel;

  const _SoundboardBottomSheet({
    required this.controller,
    required this.palette,
    required this.guild,
    required this.channel,
  });

  @override
  State<_SoundboardBottomSheet> createState() => _SoundboardBottomSheetState();
}

class _SoundboardBottomSheetState extends State<_SoundboardBottomSheet> {
  bool _loading = true;
  List<SoundboardSound> _guildSounds = const [];
  List<SoundboardSound> _otherGuildSounds = const [];
  List<SoundboardSound> _defaultSounds = const [];
  String _query = '';
  String? _playingSoundId;
  String? _statusHint;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _fetchSounds();
  }

  Future<void> _fetchSounds() async {
    final (gSounds, otherSounds, defSounds) =
        await widget.controller.loadSoundboardSounds(widget.guild.id);
    if (!mounted) return;
    setState(() {
      _guildSounds = gSounds;
      _otherGuildSounds = otherSounds;
      _defaultSounds = defSounds;
      _loading = false;
    });
  }

  Future<void> _playSound(SoundboardSound sound) async {
    if (_playingSoundId != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _playingSoundId = sound.soundId;
      _statusHint = null;
      _statusIsError = false;
    });
    try {
      await widget.controller.playSoundboardSound(widget.channel.id, sound);
      if (!mounted) return;
      setState(() {
        _statusHint = trf('正在播放：{0}', [sound.name]);
        _statusIsError = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 550));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusHint = e is Object ? '$e' : tr('播放音效失敗');
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _playingSoundId = null);
      }
    }
  }

  List<SoundboardSound> _filter(List<SoundboardSound> src) {
    if (_query.trim().isEmpty) return src;
    final q = _query.trim().toLowerCase();
    return src.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final guildFiltered = _filter(_guildSounds);
    final otherFiltered = _filter(_otherGuildSounds);
    final defaultFiltered = _filter(_defaultSounds);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: p.profileBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: p.border, width: 1.0)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note_rounded,
                          color: DiscordPalette.blurple, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('音效板'),
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: p.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: tr('搜尋音效板...'),
                      hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: p.textMuted, size: 19),
                      filled: true,
                      fillColor: p.elevatedBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_statusHint != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _statusHint!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _statusIsError
                              ? DiscordPalette.red
                              : DiscordPalette.green,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Divider(height: 1, color: p.border),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (guildFiltered.isEmpty &&
                              otherFiltered.isEmpty &&
                              defaultFiltered.isEmpty)
                          ? Center(
                              child: Text(
                                tr('找不到符合的音效'),
                                style: TextStyle(
                                    color: p.textMuted, fontSize: 14),
                              ),
                            )
                          : ListView(
                              controller: scrollCtrl,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              children: [
                                if (guildFiltered.isNotEmpty) ...[
                                  _sectionTitle(p, widget.guild.name),
                                  const SizedBox(height: 8),
                                  _buildSoundGrid(p, guildFiltered),
                                  const SizedBox(height: 18),
                                ],
                                if (defaultFiltered.isNotEmpty) ...[
                                  _sectionTitle(p, tr('Discord 預設音效')),
                                  const SizedBox(height: 8),
                                  _buildSoundGrid(p, defaultFiltered),
                                  const SizedBox(height: 18),
                                ],
                                if (otherFiltered.isNotEmpty) ...[
                                  _sectionTitle(p, tr('其他伺服器音效')),
                                  const SizedBox(height: 8),
                                  _buildSoundGrid(p, otherFiltered),
                                ],
                              ],
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(DiscordPalette p, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: p.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildSoundGrid(DiscordPalette p, List<SoundboardSound> sounds) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.9,
      ),
      itemCount: sounds.length,
      itemBuilder: (_, idx) {
        final s = sounds[idx];
        final active = _playingSoundId == s.soundId;
        final customEmoji = s.customEmojiUrl(size: 48);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _playSound(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? DiscordPalette.green.withAlpha(38)
                  : p.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? DiscordPalette.green : p.border,
                width: active ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                if (customEmoji != null)
                  Image.network(
                    customEmoji,
                    width: 22,
                    height: 22,
                    cacheWidth: 44,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.volume_up_rounded,
                      size: 20,
                      color: Colors.white70,
                    ),
                  )
                else if (s.emojiName != null && s.emojiName!.isNotEmpty)
                  Text(s.emojiName!, style: const TextStyle(fontSize: 19))
                else
                  Icon(
                    Icons.volume_up_rounded,
                    size: 20,
                    color: p.textSecondary,
                  ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (active)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DiscordPalette.green,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
