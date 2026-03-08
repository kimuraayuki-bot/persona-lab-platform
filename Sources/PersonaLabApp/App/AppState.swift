import Foundation
import PersonaLabCore

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAuthLoading = false
    @Published var quizzes: [Quiz] = [SampleData.demoQuiz]
    @Published var activeQuiz: Quiz?
    @Published var latestResult: DiagnosisResult?
    @Published var sharePayload: SharePayload?
    @Published var activeShareToken: String?
    @Published var currentUserEmail: String?
    @Published var errorMessage: String?
    @Published var authNoticeMessage: String?

    let apiClient: APIClientProtocol
    let config: AppConfig

    private let authClient: AuthClientProtocol?
    private let quizDataClient: QuizDataClientProtocol?
    private var authSession: AuthSession?

    init(
        apiClient: APIClientProtocol = MockAPIClient(),
        config: AppConfig = AppConfig(),
        authClient: AuthClientProtocol? = nil,
        quizDataClient: QuizDataClientProtocol? = nil
    ) {
        self.apiClient = apiClient
        self.config = config
        self.authClient = authClient
        self.quizDataClient = quizDataClient
    }

    static func makeDefault() -> AppState {
        if let runtime = RuntimeConfig.load() {
            let config = runtime.appConfig
            return AppState(
                apiClient: APIClient(config: config),
                config: config,
                authClient: SupabaseAuthClient(config: config),
                quizDataClient: SupabaseQuizClient(config: config)
            )
        }
        return AppState(apiClient: MockAPIClient(), config: AppConfig())
    }

    func loginWithApple() {
        errorMessage = "Appleログインは現在準備中です。メールログインを利用してください。"
    }

    func loginWithEmail(email: String, password: String, isSignUp: Bool) async {
        errorMessage = nil
        authNoticeMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください。"
            return
        }

        guard let authClient else {
            // Mock mode: allow local-only operation.
            isAuthenticated = true
            currentUserEmail = normalizedEmail
            return
        }

        isAuthLoading = true
        defer { isAuthLoading = false }

        do {
            if isSignUp {
                let signUpSession = try await authClient.signUp(email: normalizedEmail, password: password)
                if let signUpSession {
                    applySession(signUpSession, fallbackEmail: normalizedEmail)
                    await loadCreatorQuizzes()
                    return
                }

                authNoticeMessage = "仮登録が完了しました。確認メールのリンクを開いてからログインしてください。"
                return
            }

            let session = try await authClient.signIn(email: normalizedEmail, password: password)
            applySession(session, fallbackEmail: normalizedEmail)
            await loadCreatorQuizzes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upsertQuiz(_ quiz: Quiz) {
        insertOrReplaceQuiz(quiz)

        guard let session = authSession,
              let quizDataClient else {
            return
        }

        Task {
            do {
                let published = try await quizDataClient.createQuiz(quiz: quiz, creatorID: session.userID, accessToken: session.accessToken)
                insertOrReplaceQuiz(published)
            } catch {
                errorMessage = "診断の保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func buildShareMessage(for result: DiagnosisResult) async {
        do {
            let shareURL = try await makeShareURL(for: result)
            let message = "私の診断結果は \(result.type.title) でした。あなたも回答してみてください。"
            sharePayload = SharePayload(shareURL: shareURL, message: message)
        } catch {
            errorMessage = "共有リンクの作成に失敗しました: \(error.localizedDescription)"
        }
    }

    func openQuizFromLink(publicID: String, token: String?) async {
        activeShareToken = token

        if let existing = quizzes.first(where: { $0.publicID == publicID || $0.id.uuidString.lowercased() == publicID.lowercased() }) {
            activeQuiz = existing
            return
        }

        guard let quizDataClient else {
            errorMessage = "受信した診断を開くにはバックエンド設定が必要です。"
            return
        }

        do {
            if let fetched = try await quizDataClient.fetchQuiz(publicID: publicID) {
                insertOrReplaceQuiz(fetched)
                activeQuiz = fetched
            } else {
                errorMessage = "診断が見つかりませんでした。"
            }
        } catch {
            errorMessage = "診断の取得に失敗しました: \(error.localizedDescription)"
        }
    }

    private func applySession(_ session: AuthSession, fallbackEmail: String) {
        authSession = session
        currentUserEmail = session.email ?? fallbackEmail
        isAuthenticated = true
    }

    private func loadCreatorQuizzes() async {
        guard let session = authSession,
              let quizDataClient else {
            return
        }

        do {
            let remoteQuizzes = try await quizDataClient.listCreatorQuizzes(
                creatorID: session.userID,
                accessToken: session.accessToken
            )
            if !remoteQuizzes.isEmpty {
                quizzes = remoteQuizzes
            }
        } catch {
            errorMessage = "既存診断の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    private func makeShareURL(for result: DiagnosisResult) async throws -> URL {
        let accessToken = authSession?.accessToken

        if authClient != nil && (accessToken == nil || accessToken?.isEmpty == true) {
            throw APIClientError.server(statusCode: 401, message: "共有にはログインが必要です")
        }

        do {
            return try await apiClient.createShareLink(quizID: result.quizID, accessToken: accessToken).shareURL
        } catch {
            guard let session = authSession,
                  let quizDataClient,
                  let quiz = quizzes.first(where: { $0.id == result.quizID }) else {
                throw error
            }

            // If local-only quiz is selected, publish it first and retry share-link generation.
            let published = try await quizDataClient.createQuiz(quiz: quiz, creatorID: session.userID, accessToken: session.accessToken)
            insertOrReplaceQuiz(published)
            return try await apiClient.createShareLink(quizID: published.id, accessToken: session.accessToken).shareURL
        }
    }

    private func insertOrReplaceQuiz(_ quiz: Quiz) {
        if let index = quizzes.firstIndex(where: { $0.id == quiz.id || $0.publicID == quiz.publicID }) {
            quizzes[index] = quiz
        } else {
            quizzes.insert(quiz, at: 0)
        }
    }
}
