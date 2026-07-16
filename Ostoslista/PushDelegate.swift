import UIKit
import CloudKit

/// Registers a CloudKit database subscription and turns incoming silent
/// pushes into an explicit store refresh, so remote edits appear without
/// user action even when NSPersistentCloudKitContainer's own import
/// scheduling is lazy.
final class PushDelegate: NSObject, UIApplicationDelegate {
    static let pushReceived = Notification.Name("OstoslistaCloudPushReceived")
    private static let subscriptionID = "ostoslista-private-changes"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        registerSubscription()
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
