import 'package:flutter/material.dart';

import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/discord_icons.dart';

/// 1:1 faithful recreation of aiko-chan-ai/DiscordBotClient's Login UI
/// (AuthBoxTokenLogin.tsx + Discord cosmic starry login backdrop).
class LoginScreen extends StatefulWidget {
  final BotClientController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tokenCtrl = TextEditingController();
  bool _showTokenForm = false;

  @override
  void initState() {
    super.initState();
    _showTokenForm = widget.controller.savedAccounts.isEmpty;
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (widget.controller.authenticating) return;
    await widget.controller.loginWithToken(_tokenCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final hasSaved = ctrl.savedAccounts.isNotEmpty;
    final showAccountPicker = hasSaved && !_showTokenForm;

    return Scaffold(
      // Keep the backdrop full-screen behind the keyboard (resizing exposed a
      // black strip); the form scrolls above the keyboard via viewInsets.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Exact Discord Cosmic Indigo-to-Royal-Blue Starry Backdrop (matching ZGLE2Z8.png)
          const RepaintBoundary(child: _DiscordCosmicBackdrop()),

          // Top-left Discord Logo + Wordmark
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    DiscordClydeLogo(size: 28, color: Colors.white),
                    SizedBox(width: 9),
                    Text(
                      'Discord',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Centered AuthBox (#313338)
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 56, 16,
                    56 + MediaQuery.of(context).viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF313338),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x52000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: showAccountPicker
                        ? _buildAccountChooser(ctrl)
                        : _buildTokenAuthBox(ctrl, canGoBack: hasSaved),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Exact AuthBoxTokenLogin from aiko-chan-ai/VencordDBCPlugin
  Widget _buildTokenAuthBox(
    BotClientController ctrl, {
    required bool canGoBack,
  }) {
    final error = ctrl.authError;
    final hasError = error != null && error.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canGoBack) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                ctrl.clearAuthError();
                setState(() => _showTokenForm = false);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 20,
                      color: Color(0xFFB5BAC1),
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Go back',
                      style: TextStyle(
                        color: Color(0xFFF2F3F5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Welcome back!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFF2F3F5),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "We're so excited to see you again!",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFB5BAC1),
            fontSize: 15,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 22),

        // Label: BOT TOKEN (- error) matching AuthBoxTokenLogin.tsx
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'BOT TOKEN',
                style: TextStyle(
                  color: hasError
                      ? const Color(0xFFFA777C)
                      : const Color(0xFFB5BAC1),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              if (hasError) ...[
                const TextSpan(
                  text: ' - ',
                  style: TextStyle(
                    color: Color(0xFFFA777C),
                    fontSize: 12,
                  ),
                ),
                TextSpan(
                  text: error,
                  style: const TextStyle(
                    color: Color(0xFFFA777C),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Input: name="token", type="password", placeholder="Enter your bot token"
        TextField(
          controller: _tokenCtrl,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 120,
          onSubmitted: (_) => _handleSubmit(),
          style: const TextStyle(
            color: Color(0xFFF2F3F5),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter your bot token',
            hintStyle: const TextStyle(
              color: Color(0xFF80848E),
              fontSize: 15,
            ),
            filled: true,
            fillColor: const Color(0xFF1E1F22),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFFA777C)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFFA777C)
                    : const Color(0xFF00A8FC),
                width: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Button: "Login" (#5865F2)
        SizedBox(
          height: 44,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DiscordPalette.blurple,
              disabledBackgroundColor: DiscordPalette.blurple.withAlpha(140),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            onPressed: ctrl.authenticating ? null : _handleSubmit,
            child: ctrl.authenticating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Standard Discord "Choose an account" box (connects to "< Go back" in AuthBox)
  Widget _buildAccountChooser(BotClientController ctrl) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose an account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFF2F3F5),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2B2D31),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            children: ctrl.savedAccounts.asMap().entries.map((entry) {
              final idx = entry.key;
              final acc = entry.value;
              return Column(
                children: [
                  if (idx > 0)
                    const Divider(height: 1, color: Color(0xFF3F4147)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage:
                              NetworkImage(acc.avatarUrl(size: 64)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF2F3F5),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                acc.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFB5BAC1),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4E5058),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          onPressed: ctrl.authenticating
                              ? null
                              : () => ctrl.loginWithToken(acc.token),
                          child: const Text('Log in',
                              style: TextStyle(fontSize: 13.5)),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 18, color: Color(0xFFB5BAC1)),
                          onSelected: (v) {
                            if (v == 'remove') {
                              ctrl.removeSavedAccount(acc.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            ctrl.clearAuthError();
            setState(() => _showTokenForm = true);
          },
          child: const Text(
            'Add an account',
            style: TextStyle(
              color: Color(0xFFF2F3F5),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscordCosmicBackdrop extends StatelessWidget {
  const _DiscordCosmicBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CosmicBackdropPainter(),
    );
  }
}

class _CosmicBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deep purple-indigo top-left to vivid royal blue bottom-right (matching ZGLE2Z8.png)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF140942),
          Color(0xFF1A146B),
          Color(0xFF1C35B5),
          Color(0xFF0A66EE),
        ],
        stops: [0.0, 0.42, 0.78, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Soft glowing ambient orbs (imitating blurred floating Discord login artwork)
    final orb1 = Paint()
      ..color = const Color(0x337950F2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(Offset(size.width * 0.34, size.height * 0.20), 68, orb1);

    final orb2 = Paint()
      ..color = const Color(0x2E4DABF7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.38), 64, orb2);

    final orb3 = Paint()
      ..color = const Color(0x285C7CFA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    canvas.drawCircle(Offset(size.width * 0.10, size.height * 0.42), 54, orb3);

    // Subtle crisp & soft stars/sparkles scattered identically in style
    final starPaint = Paint()..color = const Color(0x55B8C7FF);
    const starPositions = <Offset>[
      Offset(0.18, 0.14),
      Offset(0.28, 0.31),
      Offset(0.45, 0.11),
      Offset(0.62, 0.18),
      Offset(0.77, 0.12),
      Offset(0.84, 0.25),
      Offset(0.15, 0.58),
      Offset(0.24, 0.74),
      Offset(0.32, 0.91),
      Offset(0.53, 0.83),
      Offset(0.79, 0.76),
      Offset(0.91, 0.65),
      Offset(0.66, 0.28),
      Offset(0.41, 0.24),
    ];
    for (final pos in starPositions) {
      final cx = size.width * pos.dx;
      final cy = size.height * pos.dy;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy), width: 5, height: 5),
        starPaint,
      );
    }

    // Four-point sparkles (+)
    final plusPaint = Paint()
      ..color = const Color(0x66B8D4FF)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (final p in const [
      Offset(0.31, 0.93),
      Offset(0.79, 0.75),
      Offset(0.93, 0.30),
      Offset(0.16, 0.56),
    ]) {
      final x = size.width * p.dx;
      final y = size.height * p.dy;
      canvas.drawLine(Offset(x - 8, y), Offset(x + 8, y), plusPaint);
      canvas.drawLine(Offset(x, y - 8), Offset(x, y + 8), plusPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
