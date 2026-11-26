import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';

/// Opens the authentic Discord Mobile Voice Channel Sheet:
/// - When NOT connected to [channel]: displays the "Join Voice" preview sheet
///   with live connected participants, start-muted mic toggle, green "加入語音" CTA,
///   and a separate "💬" Text-in-Voice chat button.
/// - When connected to [channel]: displays the full Active Voice Room with
///   live Voice RTT ping, green speaking rings (Opcode 5), participant status badges,
///   and bottom Discord Voice Control Dock (Mute, Deafen, Text-in-Voice, Hang Up).
Future<void> showVoiceChannelSheet(
  BuildContext context, {
  required BotClientController controller,
  required DiscordGuild guild,
  required DiscordChannel channel,
  required void Function(String channelId, String guildId) onOpenVoiceTextChat,
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
      );
    },
  );
}

class _VoiceChannelSheetContent extends StatefulWidget {
  final BotClientController controller;
  final DiscordGuild initialGuild;
  final DiscordChannel initialChannel;
  final void Function(String channelId, String guildId) onOpenVoiceTextChat;

  const _VoiceChannelSheetContent({
    required this.controller,
    required this.initialGuild,
    required this.initialChannel,
    required this.onOpenVoiceTextChat,
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
          SnackBar(content: Text('已複製語音頻道邀請連結：$url')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法建立邀請連結：$e')),
        );
      }
    }
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
          initialChildSize: isConnectedHere ? 0.78 : 0.60,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: p.profileBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                border: Border(
                  top: BorderSide(color: p.border, width: 1.0),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Drag pill handle
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Top Voice Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: p.textPrimary,
                              size: 28,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      channel.isStageVoice
                                          ? Icons.podcasts_rounded
                                          : Icons.volume_up_rounded,
                                      size: 19,
                                      color: isConnectedHere
                                          ? DiscordPalette.green
                                          : p.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        channel.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: p.textPrimary,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (isConnectedHere)
                                  ValueListenableBuilder<int?>(
                                    valueListenable: ctrl.voicePingMsNotifier,
                                    builder: (_, pingMs, __) {
                                      final statusText = ctrl.voiceGatewayReady
                                          ? (pingMs != null
                                              ? '語音已連線 • $pingMs ms'
                                              : '語音已連線')
                                          : '正在連線至語音閘道...';
                                      return Row(
                                        children: [
                                          Icon(
                                            Icons.signal_cellular_alt_rounded,
                                            size: 13,
                                            color: ctrl.voiceGatewayReady
                                                ? DiscordPalette.green
                                                : DiscordPalette.yellow,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              statusText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: ctrl.voiceGatewayReady
                                                    ? DiscordPalette.green
                                                    : DiscordPalette.yellow,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  )
                                else
                                  Text(
                                    channel.userLimit > 0
                                        ? '${guild.name} • 人數上限 ${participants.length}/${channel.userLimit}'
                                        : guild.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: p.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Invite button
                          IconButton(
                            tooltip: '邀請至語音頻道',
                            onPressed: () => _copyChannelInvite(channel, ctrl),
                            icon: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: p.textSecondary,
                              size: 21,
                            ),
                          ),
                          // Text-in-Voice chat button (with unread badge if unread)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                tooltip: '開啟語音文字聊天室',
                                onPressed: () => widget.onOpenVoiceTextChat(
                                  channel.id,
                                  guild.id,
                                ),
                                icon: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: p.textPrimary,
                                  size: 21,
                                ),
                              ),
                              if (hasUnreadText)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: DiscordPalette.danger,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: p.profileBg,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: p.border),

                    // Center Participant Grid / Empty Voice Lobby State
                    Expanded(
                      child: participants.isEmpty
                          ? ListView(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 32,
                              ),
                              children: [
                                const SizedBox(height: 18),
                                Center(
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: p.cardBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: p.border,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Icon(
                                      channel.isStageVoice
                                          ? Icons.podcasts_rounded
                                          : Icons.volume_up_rounded,
                                      size: 34,
                                      color: p.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '目前沒有人在語音頻道中',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '點擊下方「加入語音」即可連線進入語音頻道，或點擊右上角對話圖示檢視文字聊天室。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: p.textMuted,
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            )
                          : ValueListenableBuilder<Set<String>>(
                              valueListenable: ctrl.speakingUserIdsNotifier,
                              builder: (_, speakingIds, __) {
                                return GridView.builder(
                                  controller: scrollCtrl,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        participants.length == 1 ? 1 : 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio:
                                        participants.length == 1 ? 1.85 : 1.18,
                                  ),
                                  itemCount: participants.length,
                                  itemBuilder: (_, idx) {
                                    final vs = participants[idx];
                                    return _buildParticipantTile(
                                      ctrl: ctrl,
                                      palette: p,
                                      guild: guild,
                                      vs: vs,
                                      isSpeaking:
                                          speakingIds.contains(vs.userId),
                                    );
                                  },
                                );
                              },
                            ),
                    ),

                    // Bottom Controls: Preview Join Bar vs Active Voice Control Dock
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: isConnectedHere
                          ? _buildActiveVoiceDock(ctrl, p, guild, channel)
                          : _buildJoinPreviewBar(
                              ctrl,
                              p,
                              guild,
                              channel,
                              isConnectedElsewhere: isConnectedElsewhere,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParticipantTile({
    required BotClientController ctrl,
    required DiscordPalette palette,
    required DiscordGuild guild,
    required VoiceState vs,
    required bool isSpeaking,
  }) {
    final acc = ctrl.activeAccount;
    final isSelfBot = acc != null && vs.userId == acc.id;
    final member = vs.member ?? guild.cachedMembers[vs.userId];

    final String displayName = isSelfBot
        ? (member?.effectiveName ?? acc.displayName)
        : (member?.effectiveName ?? 'User ${vs.userId}');
    final String avatarUrl = isSelfBot
        ? acc.avatarUrl(size: 128)
        : (member != null
            ? member.user.avatarUrl(size: 128)
            : 'https://cdn.discordapp.com/embed/avatars/${((BigInt.tryParse(vs.userId) ?? BigInt.zero) >> 22).toInt().abs() % 6}.png');
    final bool isBot = isSelfBot || (member?.user.bot ?? false);
    final bool isVerifiedBot =
        isSelfBot ? acc.isVerifiedBot : (member?.user.isVerifiedBot ?? false);
    final int? roleColorInt = member?.resolveColor(guild.roles);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSpeaking ? DiscordPalette.green : palette.border,
          width: isSpeaking ? 2.2 : 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Center Avatar with Speaking Ring
          Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSpeaking ? DiscordPalette.green : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(avatarUrl),
              ),
            ),
          ),

          // Top-Right Status Badges (LIVE / Deafened / Muted)
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vs.selfStream)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: DiscordPalette.danger,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '直播',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (vs.isDeafened)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xCC111216),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.headset_off_rounded,
                      size: 14,
                      color: DiscordPalette.danger,
                    ),
                  )
                else if (vs.isMuted)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xCC111216),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_off_rounded,
                      size: 14,
                      color: DiscordPalette.danger,
                    ),
                  ),
              ],
            ),
          ),

          // Bottom-Left Member Name + APP tag
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: roleColorInt != null
                          ? Color(0xFF000000 | roleColorInt)
                          : palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isBot) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 0.8),
                    decoration: BoxDecoration(
                      color: DiscordPalette.blurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isVerifiedBot) ...[
                          const Icon(Icons.check_rounded,
                              size: 9, color: Colors.white),
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
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinPreviewBar(
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel, {
    required bool isConnectedElsewhere,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: p.bottomBarBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.border, width: 1.0),
      ),
      child: Row(
        children: [
          // Pre-join Mic Mute Toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _previewStartMuted = !_previewStartMuted);
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _previewStartMuted ? Colors.white : p.elevatedBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _previewStartMuted
                    ? Icons.mic_off_rounded
                    : Icons.mic_rounded,
                color: _previewStartMuted ? Colors.black : p.textPrimary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Prominent Discord Green "加入語音" Button
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DiscordPalette.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ctrl.joinVoiceChannel(
                    guild.id,
                    channel.id,
                    startMuted: _previewStartMuted,
                  );
                },
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                label: Text(
                  isConnectedElsewhere ? '切換至此語音頻道' : '加入語音',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Secondary Button: Open Text-in-Voice Chat without joining voice
          GestureDetector(
            onTap: () => widget.onOpenVoiceTextChat(channel.id, guild.id),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: p.elevatedBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: p.textPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveVoiceDock(
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel,
  ) {
    final muted = ctrl.selfMute;
    final deafened = ctrl.selfDeaf;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.bottomBarBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: p.border, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Mute / Unmute Mic
          _VoiceDockCircleButton(
            icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            activeWhite: muted,
            backgroundColor: p.elevatedBg,
            tooltip: muted ? '取消靜音' : '靜音',
            onTap: () {
              HapticFeedback.selectionClick();
              ctrl.toggleVoiceMute();
            },
          ),

          // 2. Deafen / Undeafen
          _VoiceDockCircleButton(
            icon:
                deafened ? Icons.headset_off_rounded : Icons.headset_rounded,
            activeWhite: deafened,
            backgroundColor: p.elevatedBg,
            tooltip: deafened ? '取消拒聽' : '拒聽',
            onTap: () {
              HapticFeedback.selectionClick();
              ctrl.toggleVoiceDeaf();
            },
          ),

          // 3. Open Voice Channel's Text-in-Voice Chat
          _VoiceDockCircleButton(
            icon: Icons.chat_bubble_outline_rounded,
            activeWhite: false,
            backgroundColor: p.elevatedBg,
            tooltip: '文字聊天室',
            onTap: () => widget.onOpenVoiceTextChat(channel.id, guild.id),
          ),

          // 4. Red Disconnect / Hang Up Pill
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await ctrl.leaveVoiceChannel();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 64,
              height: 52,
              decoration: BoxDecoration(
                color: DiscordPalette.danger,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 24,
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: activeWhite ? Colors.white : backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: activeWhite ? Colors.black : Colors.white,
            size: 23,
          ),
        ),
      ),
    );
  }
}
