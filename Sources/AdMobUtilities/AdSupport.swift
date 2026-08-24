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
            print("🟡 UMP requestConsentInfoUpdate done: status=\(ConsentInformation.shared.consentStatus.rawValue), formStatus=\(ConsentInformation.shared.formStatus.rawValue), canRequestAds=\(ConsentInformation.shared.canRequestAds), error=\(String(describing: error))")
            // canRequestAds, not the presence of an error, is the authoritative signal here —
            // e.g. "no consent forms configured for this app ID" surfaces as a non-nil error
            // even when canRequestAds is already true (nothing to show, fine to proceed), so
            // bailing out on any error would wrongly block ad loads in that case.
            if let error = error {
                print("⚠️ UMP consent info update reported an error (non-fatal if canRequestAds is true): \(error)")
            }
            ConsentForm.loadAndPresentIfRequired(from: viewController) { error in
                print("🟡 UMP loadAndPresentIfRequired done: status=\(ConsentInformation.shared.consentStatus.rawValue), canRequestAds=\(ConsentInformation.shared.canRequestAds), error=\(String(describing: error))")
                if let error = error {
                    print("⚠️ UMP consent form reported an error (non-fatal if canRequestAds is true): \(error)")
                }
                completion(ConsentInformation.shared.canRequestAds)
            }
        }
    }

    /// Whether the user needs a way to revisit/revoke their consent choice (GDPR requirement) —
    /// check this before showing a "privacy choices" entry point in app UI, since it's only
    /// meaningful for users the consent flow actually applied to.
    public static var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    public static func presentPrivacyOptionsForm(
        from viewController: UIViewController?,
        completion: @escaping (Error?) -> Void
    ) {
        ConsentForm.presentPrivacyOptionsForm(from: viewController, completionHandler: completion)
    }
}
