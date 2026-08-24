import Foundation
import UIKit
import UserMessagingPlatform

// Google requires the UMP consent flow to run, and complete, before any ad request for
// UK/EEA users (EU User Consent Policy) — this must be called once per app session before
// any ad is loaded. loadAndPresentIfRequired is a no-op (immediate completion) when no form
// is actually required, so it's safe to call unconditionally every session.
@MainActor
public enum AdConsentManager {
    public static func requestConsentAndLoadAdsIfPossible(
        from viewController: UIViewController?,
        completion: @escaping (Bool) -> Void
    ) {
        let parameters = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
            if let error = error {
                print("⚠️ UMP consent info update failed: \(error)")
                completion(false)
                return
            }
            ConsentForm.loadAndPresentIfRequired(from: viewController) { error in
                if let error = error {
                    print("⚠️ UMP consent form failed: \(error)")
                }
                completion(ConsentInformation.shared.canRequestAds)
            }
        }
    }
}
