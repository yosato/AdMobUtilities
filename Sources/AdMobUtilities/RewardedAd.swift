import SwiftUI
import UIKit
import GoogleMobileAds

@MainActor
public class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published public var isAdReady = false
    private var rewardedAd: RewardedAd?
    private let adUnitID: String
    public var onDismiss: (() -> Void)?

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
        load()
    }

    public func load() {
        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let ad else { return }
            nonisolated(unsafe) let loadedAd = ad
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rewardedAd = loadedAd
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdReady = true
            }
        }
    }

    // userDidEarnRewardHandler fires only on a genuine completed watch — dismissing early
    // (adDidDismissFullScreenContent below) without it firing means no reward, by AdMob's own
    // contract, so callers don't need to separately track "did they actually finish."
    public func show(from viewController: UIViewController, onUserEarnedReward: @escaping () -> Void) {
        guard let rewardedAd else { return }
        rewardedAd.present(from: viewController, userDidEarnRewardHandler: onUserEarnedReward)
    }

    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isAdReady = false
        rewardedAd = nil
        onDismiss?()
        load()
    }

    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Rewarded ad failed to present: \(error)")
        isAdReady = false
        load()
    }
}
