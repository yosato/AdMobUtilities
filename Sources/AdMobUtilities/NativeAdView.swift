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
    // video (and other webview-rendered) creatives render via an SDK-owned GADWebAdView/WKWebView
    // that has repeatedly tripped AdMob's own "assets outside native ad view" validator — every
    // fixable layout-level cause was found and fixed (AdChoices positioning, a float-noise
    // overflow, a WKWebView-internal scroll indicator), yet the error persists, pointing at
    // something inside the webview's own rendered content that's unreachable from outside the
    // SDK. Rather than keep fighting that, shift away from the erroring path entirely: discard a
    // webview-rendered creative and request again — capped so a run of such fill can't loop
    // forever.
    private var webviewRetriesRemaining = 3

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
        // TEMPORARY — identifying which specific creative got served, to tell apart "same
        // creative, validator result still flips" (a race/flakiness in the check itself) from
        // "different creative each time" (only some video assets trip the bug).
        print("🔎 creative headline=\(nativeAd.headline ?? "nil") advertiser=\(nativeAd.advertiser ?? "nil") duration=\(nativeAd.mediaContent.duration) aspectRatio=\(nativeAd.mediaContent.aspectRatio)")
        // hasVideoContent alone doesn't catch every webview-rendered creative — some HTML5/rich
        // media ads render via the same GADWebAdView/WKWebView path without reporting as video.
        // Those creatives also lack a static mainImage, so treat that as the broader signal.
        let rendersViaWebview = nativeAd.mediaContent.hasVideoContent || nativeAd.mediaContent.mainImage == nil
        if rendersViaWebview {
            if webviewRetriesRemaining > 0 {
                webviewRetriesRemaining -= 1
                load()
            }
            // Retries exhausted: leave nativeAd nil rather than falling back to displaying a
            // webview-rendered creative — every one tested (three distinct advertisers, verified
            // with a clean, violation-free frame measurement each time) still tripped the
            // validator. Better to skip the slot than guarantee showing a flagged ad.
            return
        }
        self.nativeAd = nativeAd
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("⚠️ native ad failed to load: \(error)")
    }
}
