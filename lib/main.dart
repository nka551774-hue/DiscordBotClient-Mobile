import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state/bot_client_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
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

  @override
  void initState() {
    super.initState();
    _controller = BotClientController()..init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final oled = _controller.ecoSettings.oledBlackMode;

        return MaterialApp(
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
