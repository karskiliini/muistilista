import UIKit
import CloudKit

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Family member tapped the invite link and accepted the share.
    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        AppStores.provider?.acceptShare(metadata: cloudKitShareMetadata)
    }
}
