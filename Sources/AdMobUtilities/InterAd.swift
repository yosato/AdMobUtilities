import SwiftUI
import UIKit
import GoogleMobileAds

@MainActor
public class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published public var isAdReady = false
    private var interstitial: InterstitialAd?
    private let adUnitID: String
    public var onDismiss:(()->Void)?

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
        load()
    }

    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isAdReady = false
        interstitial = nil
        onDismiss?()
        load()
    }
    
    public func load() {
        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let ad else { return }
            nonisolated(unsafe) let loadedAd = ad
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.interstitial = loadedAd
                self.interstitial?.fullScreenContentDelegate = self
                self.isAdReady = true
            }
        }
    }
    
    public func show(from viewController: UIViewController) {
        guard let interstitial else { return }
        interstitial.present(from: viewController)
    }


    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Interstitial failed to present: \(error)")
        isAdReady = false
        load()
    }
}

public func rootViewController() -> UIViewController? {
    var vc = UIApplication.shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController
    while let presented = vc?.presentedViewController {
        vc = presented
    }
    return vc
}
