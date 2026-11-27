import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';

/// Official mobile in-app notification: a card that slides down from the top
/// for a new DM or mention, auto-hides after a few seconds, tap to open,
/// swipe up to dismiss.
class InAppNotificationBanner extends StatefulWidget {
  final BotClientController controller;
  final void Function(DiscordMessage msg) onOpen;

  const InAppNotificationBanner({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner> {
  DiscordMessage? _msg;
  bool _visible = false;
  Timer? _hideTimer;

  ValueNotifier<DiscordMessage?> get _notifier =>
      widget.controller.inAppNotificationNotifier;

  @override
  void initState() {
    super.initState();
    _notifier.addListener(_onMessage);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onMessage);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onMessage() {
    final msg = _notifier.value;
    if (msg == null || !mounted) return;
    setState(() {
      _msg = msg;
      _visible = true;
    });
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), _hide);
  }

  void _hide() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _visible = false);
  }

  String _preview(DiscordMessage msg) {
    final ctrl = widget.controller;
    var text = msg.content
        .replaceAllMapped(RegExp(r'<@!?(\d+)>'), (m) {
          final u = ctrl.getCachedUser(m.group(1)!);
          return '@${u?.displayName ?? 'user'}';
        })
        .replaceAllMapped(RegExp(r'<a?:(\w+):\d+>'), (m) => ':${m.group(1)}:')
        .replaceAllMapped(RegExp(r'<#(\d+)>'),
            (m) => '#${ctrl.findChannelById(m.group(1)!)?.name ?? ''}')
        .trim();
    if (text.isEmpty) text = tr('[Embed / 附件]');
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final msg = _msg;
    final top = MediaQuery.of(context).padding.top + 8;
    if (msg == null) return const SizedBox.shrink();

    final ctrl = widget.controller;
    DiscordGuild? guild;
    for (final g in ctrl.guilds) {
      if (g.id == msg.guildId) guild = g;
    }
    final channel = ctrl.findChannelById(msg.channelId);
    final subtitle = guild == null
        ? null
        : '${guild.name} · #${channel?.name ?? ''}';

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      top: _visible ? top : -140,
      left: 8,
      right: 8,
      child: IgnorePointer(
        ignoring: !_visible,
        child: GestureDetector(
          onTap: () {
            _hide();
            widget.onOpen(msg);
          },
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < 0) _hide();
          },
          child: Material(
            color: const Color(0xFF2B2D31),
            elevation: 10,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        NetworkImage(msg.author.avatarUrl(size: 96)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg.authorDisplayName(guild),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB5BAC1),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          _preview(msg),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFDBDEE1),
                            fontSize: 14,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
