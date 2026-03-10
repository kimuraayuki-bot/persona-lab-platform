import Foundation

enum AdMobConfig {
    enum BannerPlacement {
        case home
        case result
    }

    static let applicationID = "ca-app-pub-8632161441155952~3552623078"
    static let homeBannerAdUnitID = "ca-app-pub-8632161441155952/2536364383"
    static let resultBannerAdUnitID = "ca-app-pub-8632161441155952/1453907491"
    static let debugBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    static func activeBannerAdUnitID(for placement: BannerPlacement) -> String {
#if DEBUG
        return debugBannerAdUnitID
#else
        switch placement {
        case .home:
            return homeBannerAdUnitID
        case .result:
            return resultBannerAdUnitID
        }
#endif
    }
}
