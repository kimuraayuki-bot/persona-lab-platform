import Foundation

@MainActor
enum DeepLinkHandler {
    static func handle(_ url: URL, state: AppState) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let quizPublicID: String?
        if url.scheme == "myapp", url.host == "quiz" {
            quizPublicID = url.pathComponents.dropFirst().first
        } else if (url.scheme == "https" || url.scheme == "http"), url.pathComponents.count >= 3, url.pathComponents[1] == "q" {
            quizPublicID = url.pathComponents[2]
        } else {
            quizPublicID = nil
        }

        guard let targetPublicID = quizPublicID else { return }
        let token = components.queryItems?.first(where: { $0.name == "token" })?.value

        Task {
            await state.openQuizFromLink(publicID: targetPublicID, token: token)
        }
    }
}
