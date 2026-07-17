import UIKit
import CloudKit
import UserNotifications

/// Registers a CloudKit database subscription and turns incoming silent
/// pushes into an explicit store refresh, so remote edits appear without
/// user action even when NSPersistentCloudKitContainer's own import
/// scheduling is lazy.
final class PushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let pushReceived = Notification.Name("OstoslistaCloudPushReceived")
    private static let subscriptionID = "ostoslista-private-changes"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Skip push setup (and its permission prompt) in screenshot/UI-test runs.
        let args = ProcessInfo.processInfo.arguments
        guard !args.contains("-Screenshots"), !args.contains("-UITestReset") else { return true }
        application.registerForRemoteNotifications()
        registerSubscription()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        NotificationCenter.default.post(name: Self.pushReceived, object: nil)
        // Give the refresh a moment to import before reporting back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            completionHandler(.newData)
        }
    }

    /// Route scene events through our delegate so CloudKit share
    /// invitations reach the app (CKSharingSupported flow).
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    /// Show remote-change banners also while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    private func registerSubscription() {
        let subscription = CKDatabaseSubscription(subscriptionID: Self.subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        CKContainer(identifier: CoreDataStack.cloudKitContainerID)
            .privateCloudDatabase
            .save(subscription) { _, _ in /* re-saving an existing subscription is harmless */ }
    }
}
