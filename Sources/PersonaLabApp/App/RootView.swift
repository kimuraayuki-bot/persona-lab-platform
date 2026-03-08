import SwiftUI
import PersonaLabCore

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Group {
            if state.isAuthenticated {
                QuizListView()
            } else {
                LoginView()
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.errorMessage ?? "不明なエラー")
        }
        .onOpenURL { url in
            DeepLinkHandler.handle(url, state: state)
        }
    }
}
