import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'user_profile_sheet.dart';

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
                                    builder: (_, voicePingMs, __) {
                                      final connected = ctrl.isVoiceConnected;
                                      final effectivePing = voicePingMs ??
                                          ctrl.pingMsNotifier.value;
                                      final statusText = connected
                                          ? (effectivePing != null
                                              ? '語音已連線 • $effectivePing ms'
                                              : '語音已連線')
                                          : '連線中...';
                                      return Row(
                                        children: [
                                          Icon(
                                            Icons.signal_cellular_alt_rounded,
                                            size: 13,
                                            color: connected
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
                                                color: connected
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
                                      context: context,
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
                          ? _buildActiveVoiceDock(
                              context,
                              ctrl,
                              p,
                              guild,
                              channel,
                            )
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
    required BuildContext context,
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
            ? member.effectiveAvatarUrl(guild.id, size: 128)
            : 'https://cdn.discordapp.com/embed/avatars/${((BigInt.tryParse(vs.userId) ?? BigInt.zero) >> 22).toInt().abs() % 6}.png');
    final bool isBot = isSelfBot || (member?.user.bot ?? false);
    final bool isVerifiedBot =
        isSelfBot ? acc.isVerifiedBot : (member?.user.isVerifiedBot ?? false);
    final int? roleColorInt = member?.resolveColor(guild.roles);

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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

            // Bottom Member Name + APP tag
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
    BuildContext context,
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel channel,
  ) {
    final muted = ctrl.selfMute;
    final deafened = ctrl.selfDeaf;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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

          // 3. Soundboard (音效板)
          _VoiceDockCircleButton(
            icon: Icons.music_note_rounded,
            activeWhite: false,
            backgroundColor: p.elevatedBg,
            tooltip: '音效板',
            onTap: () {
              HapticFeedback.selectionClick();
              _openSoundboardModal(context, ctrl, p, guild, channel);
            },
          ),

          // 4. Open Voice Channel's Text-in-Voice Chat
          _VoiceDockCircleButton(
            icon: Icons.chat_bubble_outline_rounded,
            activeWhite: false,
            backgroundColor: p.elevatedBg,
            tooltip: '文字聊天室',
            onTap: () => widget.onOpenVoiceTextChat(channel.id, guild.id),
          ),

          // 5. Red Disconnect / Hang Up Pill
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await ctrl.leaveVoiceChannel();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 58,
              height: 48,
              decoration: BoxDecoration(
                color: DiscordPalette.danger,
                borderRadius: BorderRadius.circular(24),
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
        _statusHint = '正在播放：${sound.name}';
        _statusIsError = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 550));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusHint = e is Object ? '$e' : '播放音效失敗';
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
                          '音效板',
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
                      hintText: '搜尋音效板...',
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
                                '找不到符合的音效',
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
                                  _sectionTitle(p, 'Discord 預設音效'),
                                  const SizedBox(height: 8),
                                  _buildSoundGrid(p, defaultFiltered),
                                  const SizedBox(height: 18),
                                ],
                                if (otherFiltered.isNotEmpty) ...[
                                  _sectionTitle(p, '其他伺服器音效'),
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
