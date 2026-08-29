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
        // landscape, not .any/.unknown (the prior nil-options default): a wider-than-tall
        // creative gives a shorter height at a fixed card width, unlike a square/portrait one.
        // This is the SDK's actual documented lever for influencing creative shape — everything
        // tried purely in the rendering layer (fixed height, narrower mediaView, narrower card)
        // was ignored by some creatives' own internal sizing regardless of our constraints.
        let mediaOptions = NativeAdMediaAdLoaderOptions()
        mediaOptions.mediaAspectRatio = .landscape
        let loader = AdLoader(adUnitID: adUnitID, rootViewController: rootVC, adTypes: [.native], options: [mediaOptions])
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
