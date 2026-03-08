import SwiftUI

@main
struct PersonaLabApp: App {
    @StateObject private var state = AppState.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
        }
    }
}
