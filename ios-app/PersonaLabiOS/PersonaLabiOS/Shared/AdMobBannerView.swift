import SwiftUI

#if canImport(UIKit) && canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit

struct AdMobBannerView: View {
    let placement: AdMobConfig.BannerPlacement

    @State private var availableWidth = UIScreen.main.bounds.width - 32

    var body: some View {
        let width = max(availableWidth, 320)
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)

        BannerViewContainer(
            adSize: adSize,
            adUnitID: AdMobConfig.activeBannerAdUnitID(for: placement)
        )
            .frame(width: adSize.size.width, height: adSize.size.height)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            availableWidth = geometry.size.width
                        }
                        .onChange(of: geometry.size.width) { _, newValue in
                            availableWidth = newValue
                        }
                }
            )
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    typealias UIViewType = BannerView

    let adSize: AdSize
    let adUnitID: String

    func makeCoordinator() -> BannerCoordinator {
        BannerCoordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.topViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = UIApplication.topViewController()

        let currentSize = uiView.adSize.size
        let targetSize = adSize.size
        guard currentSize != targetSize else { return }

        uiView.adSize = adSize
        uiView.load(Request())
    }
}

private final class BannerCoordinator: NSObject, BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("AdMob banner loaded.")
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("AdMob banner failed: \(error.localizedDescription)")
    }
}

private extension UIApplication {
    static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = base as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return topViewController(base: selected)
        }

        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }

        return base
    }
}
#else
struct AdMobBannerView: View {
    let placement: AdMobConfig.BannerPlacement

    var body: some View {
        EmptyView()
    }
}
#endif
