import SwiftUI
import UIKit
import GoogleMobileAds

public struct BannerAdView: View {
    @State private var isAdMobReady = false
    private let adUnitID: String

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public var body: some View {
        VStack {
            if isAdMobReady {
                RealBannerAdView(adUnitID: adUnitID)
            } else {
                PlaceholderAdView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isAdMobReady = true
            }
        }
    }
}

public struct PlaceholderAdView: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 320, height: 50)
            .overlay(Text("").foregroundColor(.black))
    }
}

public struct RealBannerAdView: UIViewRepresentable {
    public typealias UIViewType = BannerView

    public let adUnitID: String

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID

        bannerView.rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        bannerView.load(Request())
        return bannerView
    }

    public func updateUIView(_ uiView: BannerView, context: Context) {}
}
