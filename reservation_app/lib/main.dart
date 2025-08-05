// main.dart

import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

import 'splash_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'admin_screen.dart';
import 'operator_screen.dart';

/// バックグラウンドでプッシュ通知を受け取ったとき
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  '高優先度通知',
  description: '重要な通知用チャネル',
  importance: Importance.high,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final initSettings = kIsWeb
      ? const InitializationSettings(android: androidInit)
      : const InitializationSettings(
          android: androidInit,
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse resp) {
      Navigator.of(navigatorKey.currentContext!)
          .pushNamed('/notification_detail');
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final FirebaseMessaging _messaging;

  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    _messaging = FirebaseMessaging.instance;

    // 通知の権限リクエスト
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // iOS では APNs トークンを先に取ってみる（例外許容）
      if (!kIsWeb && Platform.isIOS) {
        try {
          final apnsToken = await _messaging.getAPNSToken();
          debugPrint('APNS token: $apnsToken');
        } catch (e) {
          debugPrint('APNS token not available: $e');
        }
      }

      // FCM トークン取得（シミュレータでも例外で落ちないように try/catch）
      String? fcmToken;
      try {
        fcmToken = await _messaging.getToken();
        debugPrint('FCM token: $fcmToken');
      } catch (e) {
        debugPrint('Failed to get FCM token: $e');
      }

      // Firestore に保存
      final user = FirebaseAuth.instance.currentUser;
      if (fcmToken != null && user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': fcmToken});
      }

      // トークン更新時も同様に
      // トークン更新時も同様に
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          final u = FirebaseAuth.instance.currentUser;
          if (u != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(u.uid)
                .update({'fcmToken': newToken});
          }
        } catch (e) {
          debugPrint('Failed to refresh FCM token: $e');
        }
      });

      // topic subscribe は失敗してもクラッシュさせない
      try {
        await _messaging.subscribeToTopic('all');
      } catch (e) {
        debugPrint('Failed to subscribe to topic: $e');
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        final n = msg.notification;
        final a = msg.notification?.android;
        if (n != null && a != null) {
          flutterLocalNotificationsPlugin.show(
            n.hashCode,
            n.title,
            n.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: kIsWeb ? null : const DarwinNotificationDetails(),
              macOS: kIsWeb ? null : const DarwinNotificationDetails(),
            ),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
        navigatorKey.currentState?.pushNamed('/notification_detail');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'マンション予約管理アプリ',
      initialRoute: '/splash',
      routes: {
        '/splash': (c) => const SplashScreen(),
        '/login': (c) => LoginScreen(),
        '/main': (c) => const MainScreen(),
        '/admin_dashboard': (c) => AdminScreen(),
        '/operator_dashboard': (c) => const OperatorScreen(),
        '/notification_detail': (c) => const MainScreen(initialTabIndex: 3),
      },
      locale: const Locale('ja'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja')],
      theme: ThemeData(primarySwatch: Colors.blue),
    );
  }
}
