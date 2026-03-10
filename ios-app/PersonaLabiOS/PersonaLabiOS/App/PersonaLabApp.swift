import SwiftUI

@main
struct PersonaLabApp: App {
    @StateObject private var state = AppState.makeDefault()

    init() {
        AdMobBootstrap.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
        }
    }
}

#if canImport(GoogleMobileAds)
import GoogleMobileAds

private enum AdMobBootstrap {
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        MobileAds.shared.start()
    }
}
#else
private enum AdMobBootstrap {
    static func start() {}
}
#endif
