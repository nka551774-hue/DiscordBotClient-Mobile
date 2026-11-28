import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/strings.dart';
import 'state/bot_client_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.load();
  // Draw behind status / navigation bars; each screen paints its own colour there.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const DiscordBotClientMobileApp());
}

class DiscordBotClientMobileApp extends StatefulWidget {
  const DiscordBotClientMobileApp({super.key});

  @override
  State<DiscordBotClientMobileApp> createState() =>
      _DiscordBotClientMobileAppState();
}

class _DiscordBotClientMobileAppState extends State<DiscordBotClientMobileApp> {
  late final BotClientController _controller;
  // Only what the app shell shows; screens listen to the controller
  // themselves, so a gateway event no longer rebuilds MaterialApp + theme.
  final ValueNotifier<String> _shell = ValueNotifier<String>('');

  String _shellKey() => '${_controller.initializing}|'
      '${_controller.activeAccount?.id}|'
      '${_controller.ecoSettings.oledBlackMode}';

  void _onControllerChanged() => _shell.value = _shellKey();

  @override
  void initState() {
    super.initState();
    _controller = BotClientController()..init();
    _shell.value = _shellKey();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_shell, AppLanguage.current]),
      builder: (context, _) {
        final oled = _controller.ecoSettings.oledBlackMode;
        final lang = AppLanguage.current.value;

        // Keyed by language so every screen rebuilds its tr() strings.
        return MaterialApp(
          key: ValueKey(lang),
          title: 'Discord',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(oledBlack: oled),
          home: _controller.initializing
              ? Scaffold(
                  backgroundColor:
                      oled ? Colors.black : const Color(0xFF1E1F22),
                  body: const Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : (_controller.activeAccount == null
                  ? LoginScreen(controller: _controller)
                  : HomeScreen(controller: _controller)),
        );
      },
    );
  }
}
