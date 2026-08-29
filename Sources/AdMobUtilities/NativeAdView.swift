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
    // video (and other webview-rendered) creatives sometimes trip AdMob's own "assets outside
    // native ad view" validator — a known, long-open issue in Google's SDK (matching public
    // GitHub issues against the same underlying SDK), not something reachable from this app's
    // code: every layout-level cause we could control was found and fixed (AdChoices positioning,
    // a float-noise overflow, a WKWebView-internal scroll indicator), yet it still surfaces on
    // some creatives. Discard a webview-rendered creative and request again rather than risk
    // displaying one — capped so a run of such fill can't loop forever.
    // 20: covers even a pessimistic 15-20% real-world static-image fill rate with >95% odds of
    // landing one before giving up (a 1000-retry test today confirmed this specific test ad pool
    // is ~100% video, so it can't validate that assumption — this is a bet on real production
    // inventory being more diverse than Google's fixed test rotation). Each retry is a real
    // network round-trip in production, so much higher risks a visibly slow ad load.
    private var webviewRetriesRemaining = 20

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
        // the SDK's own default play/pause/mute control overlay (visible on a video creative) is
        // a separate, SDK-owned rendering layer we have zero control over — a real suspect for
        // content painting past adView's bounds regardless of our own constraints/clipsToBounds.
        // Requesting custom controls removes that overlay entirely; we don't build replacement
        // controls, so video just autoplays muted with none — an acceptable simplification while
        // isolating whether that overlay was the actual cause.
        let videoOptions = VideoOptions()
        videoOptions.areCustomControlsRequested = true
        let loader = AdLoader(adUnitID: adUnitID, rootViewController: rootVC, adTypes: [.native], options: [mediaOptions, videoOptions])
        loader.delegate = self
        adLoader = loader
        loader.load(Request())
    }
}

extension NativeAdLoader: NativeAdLoaderDelegate {
    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        // TEMPORARY — identifying which specific creative got served each retry. Commented out,
        // not deleted.
        // print("🔎 creative headline=\(nativeAd.headline ?? "nil") advertiser=\(nativeAd.advertiser ?? "nil") duration=\(nativeAd.mediaContent.duration) aspectRatio=\(nativeAd.mediaContent.aspectRatio) hasVideoContent=\(nativeAd.mediaContent.hasVideoContent) mainImage=\(nativeAd.mediaContent.mainImage == nil ? "nil" : "present") retriesLeft=\(webviewRetriesRemaining)")
        let rendersViaWebview = nativeAd.mediaContent.hasVideoContent || nativeAd.mediaContent.mainImage == nil
        if rendersViaWebview {
            if webviewRetriesRemaining > 0 {
                webviewRetriesRemaining -= 1
                load()
            } else {
                // TEMPORARY — distinguishing "we gave up" (this line) from "the ad server gave
                // up" (the didFailToReceiveAdWithError print below), since a stopped retry chain
                // could be caused by either one, and only this line means our own cap was hit.
                // print("🔎 RETRY CAP HIT — webviewRetriesRemaining reached 0, giving up ourselves")
            }
            return
        }
        self.nativeAd = nativeAd
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        // TEMPORARY — see the retry-cap print above: this firing means the AD SERVER stopped the
        // chain (no fill / throttled / rate-limited), not our own retry cap.
        // print("🔎 AD SERVER FAILURE — didFailToReceiveAdWithError fired, chain stopped server-side")
        print("⚠️ native ad failed to load: \(error)")
    }
}
