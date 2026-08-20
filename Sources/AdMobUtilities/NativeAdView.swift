import Foundation
import UIKit
import GoogleMobileAds

// Loading only — deliberately no rendering here. Native ads exist specifically so each app can
// build its own on-brand template (see BannerAdView/InterstitialAdManager for the generic,
// SDK-rendered formats, which genuinely are the same across any app). Consumers get the raw
// NativeAd via `nativeAd` and build their own SwiftUI/UIKit card around it.
@MainActor
public final class NativeAdLoader: NSObject, ObservableObject {
    @Published public var nativeAd: NativeAd?
    private var adLoader: AdLoader?
    private let adUnitID: String

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public func load() {
        guard let rootVC = rootViewController() else { return }
        let loader = AdLoader(adUnitID: adUnitID, rootViewController: rootVC, adTypes: [.native], options: nil)
        loader.delegate = self
        adLoader = loader
        loader.load(Request())
    }
}

extension NativeAdLoader: NativeAdLoaderDelegate {
    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("⚠️ native ad failed to load: \(error)")
    }
}
