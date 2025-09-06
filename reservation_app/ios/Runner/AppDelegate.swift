import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ▼Firebase 詳細ログ（必要なければ削除可）
    FirebaseConfiguration.shared.setLoggerLevel(.debug)

    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    // ▼FCM delegate（トークン更新などを受ける）
    Messaging.messaging().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNs の deviceToken を FCM にブリッジ＋ログ出力
  override func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("📬 APNs deviceToken (hex) = \(hex)")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // FCM の登録トークン（更新含む）
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔑 FCM registration token: \(String(describing: fcmToken))")
  }

  // フォアグラウンド表示（親にある実装をオーバーライド）
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // iOS 14+ なら .banner、下位互換も考えるなら .alert を併記
    completionHandler([.banner, .sound, .badge])
  }
}
