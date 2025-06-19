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

/// バックグラウンドでプッシュ通知を受け取ったときのハンドラー
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 必要ならここで flutter_local_notifications を使って通知表示
}

/// flutter_local_notifications 用プラグインインスタンス
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android の通知チャネル
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // 任意のID
  '高優先度通知', // ユーザーに見える名前
  description: '重要な通知用チャネル',
  importance: Importance.high,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // バックグラウンドメッセージハンドラー登録
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // flutter_local_notifications の初期化
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = IOSInitializationSettings();
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onSelectNotification: (payload) async {
      // ユーザーが通知をタップしたときの処理
      if (payload != null) {
        // たとえば、payload に通知ドキュメントIDを渡して詳細画面へ
        Navigator.of(navigatorKey.currentContext!)
            .pushNamed('/notification_detail', arguments: payload);
      }
    },
  );

  // Android ではチャネルを作成
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const MyApp());
}

/// グローバルな navigatorKey を用意しておくと、
/// 通知タップ時にどこからでも Navigator が使える
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

  void _setupFCM() async {
    _messaging = FirebaseMessaging.instance;

    // iOS の通知権限をリクエスト
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // デバイストークンを取得して Firestore に保存
      final token = await _messaging.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': token});
        }
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': newToken});
        }
      });

      // "all" 向け Topic にサブスクライブ
      await _messaging.subscribeToTopic('all');

      // フォアグラウンド通知のハンドリング
      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        final notification = msg.notification;
        final android = msg.notification?.android;
        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: IOSNotificationDetails(),
            ),
            payload: msg.data['docId'], // 通知ドキュメントIDなど
          );
        }
      });

      // 通知タップ（アプリがバックグラウンド or 終了状態）で起動したとき
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
        final docId = msg.data['docId'];
        if (docId != null) {
          navigatorKey.currentState
              ?.pushNamed('/notification_detail', arguments: docId);
        }
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
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/admin_dashboard': (context) => const AdminScreen(),
        '/operator_dashboard': (context) => const OperatorScreen(),
        // 通知詳細画面のルート例
        '/notification_detail': (context) {
          final docId = ModalRoute.of(context)!.settings.arguments as String;
          // ここで docId を受け取り、Firestore から通知内容をフェッチして表示する画面へ
          return NotificationDetailScreen(notificationId: docId);
        },
      },
      locale: const Locale('ja'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''),
      ],
      theme: ThemeData(primarySwatch: Colors.blue),
    );
  }
}
