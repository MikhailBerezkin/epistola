import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/app_settings.dart';
import 'services/notification_service.dart';
import 'services/push/push_deep_link_navigation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final pushDeepLinkNavigation = PushDeepLinkNavigation();

  await NotificationService.initialize(
    deepLinkCoordinator: pushDeepLinkNavigation.coordinator,
  );

  await AppSettings.loadThemeMode();

  runApp(EpistolaApp(pushDeepLinkNavigation: pushDeepLinkNavigation));

  unawaited(NotificationService.startMessaging());
}

class EpistolaApp extends StatefulWidget {
  const EpistolaApp({super.key, required this.pushDeepLinkNavigation});

  final PushDeepLinkNavigation pushDeepLinkNavigation;

  @override
  State<EpistolaApp> createState() => _EpistolaAppState();
}

class _EpistolaAppState extends State<EpistolaApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.pushDeepLinkNavigation.markNavigationReady();
    });
  }

  @override
  void dispose() {
    widget.pushDeepLinkNavigation.markNavigationUnavailable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: widget.pushDeepLinkNavigation.navigatorKey,
          title: 'Epistola',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: FirebaseAuth.instance.currentUser != null
              ? const HomeScreen()
              : const WelcomeScreen(),
        );
      },
    );
  }
}
