import SwiftUI

#if canImport(UIKit) && canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit

struct AdMobBannerView: View {
    let placement: AdMobConfig.BannerPlacement

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width - 16, 1)

            Group {
                if width > 1 {
                    let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)

                    BannerViewContainer(
                        adSize: adSize,
                        adUnitID: AdMobConfig.activeBannerAdUnitID(for: placement)
                    )
                    .frame(width: adSize.size.width, height: adSize.size.height)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(PopTheme.cardFill)
                            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
                    )
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                availableWidth = width
            }
            .onChange(of: width) { _, newValue in
                availableWidth = newValue
            }
        }
        .frame(height: bannerHeight(for: availableWidth))
    }

    private func bannerHeight(for width: CGFloat) -> CGFloat {
        guard width > 1 else {
            return 0
        }

        return currentOrientationAnchoredAdaptiveBanner(width: width).size.height + 12
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
