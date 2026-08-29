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
    // video creatives render via an SDK-owned webview (GADWebAdView inside MediaView) that has
    // repeatedly ignored every layout constraint/clip we've tried, tripping AdMob's own "assets
    // outside native ad view" validator independent of anything in this app's code. Rather than
    // keep fighting that rendering path, videoRetriesRemaining lets didReceive discard a video
    // creative and request again — capped so a run of video-only fill can't loop forever.
    private var videoRetriesRemaining = 3

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
        if nativeAd.mediaContent.hasVideoContent, videoRetriesRemaining > 0 {
            videoRetriesRemaining -= 1
            load()
            return
        }
        self.nativeAd = nativeAd
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("⚠️ native ad failed to load: \(error)")
    }
}
