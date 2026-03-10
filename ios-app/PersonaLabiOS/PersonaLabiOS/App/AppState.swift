import Foundation
import Combine

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
    private let imageStore = CharacterImageStore.shared

    private let authClient: AuthClientProtocol?
    private let quizDataClient: QuizDataClientProtocol?
    private var authSession: AuthSession?
    private let skipLoginForDev: Bool

    init(
        apiClient: APIClientProtocol = MockAPIClient(),
        config: AppConfig = AppConfig(),
        authClient: AuthClientProtocol? = nil,
        quizDataClient: QuizDataClientProtocol? = nil,
        skipLoginForDev: Bool = false
    ) {
        self.apiClient = apiClient
        self.config = config
        self.authClient = authClient
        self.quizDataClient = quizDataClient
        self.skipLoginForDev = skipLoginForDev

        if skipLoginForDev {
            applyDevBypassIdentityIfNeeded()
        }
    }

    static func makeDefault() -> AppState {
        let env = ProcessInfo.processInfo.environment
        let useMockAPI = RuntimeConfig.shouldUseMockAPI(env: env)
        let skipLoginForDev = RuntimeConfig.shouldSkipLoginForDev(env: env) || useMockAPI

        if let runtime = RuntimeConfig.load(env: env) {
            let config = runtime.appConfig
            return AppState(
                apiClient: APIClient(config: config),
                config: config,
                authClient: SupabaseAuthClient(config: config),
                quizDataClient: SupabaseQuizClient(config: config),
                skipLoginForDev: skipLoginForDev
            )
        }

        return AppState(
            apiClient: MockAPIClient(),
            config: AppConfig(),
            skipLoginForDev: skipLoginForDev
        )
    }

    func logout() {
        authSession = nil
        activeQuiz = nil
        latestResult = nil
        activeShareToken = nil
        sharePayload = nil
        authNoticeMessage = nil
        errorMessage = nil
        quizzes = [SampleData.demoQuiz]

        if skipLoginForDev {
            applyDevBypassIdentityIfNeeded()
        } else {
            isAuthenticated = false
            currentUserEmail = nil
        }
    }

    func loginWithEmail(email: String, password: String, isSignUp: Bool) async {
        errorMessage = nil
        authNoticeMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if skipLoginForDev {
            isAuthenticated = true
            currentUserEmail = normalizedEmail.isEmpty ? "dev-preview@local" : normalizedEmail
            return
        }

        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください。"
            return
        }

        guard let authClient else {
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
        let existing = quizzes.first(where: { $0.id == quiz.id || $0.publicID == quiz.publicID })
        insertOrReplaceQuiz(quiz)

        guard let session = authSession,
              let quizDataClient else {
            return
        }

        let shouldUpdateRemote = (existing?.creatorID != nil) || (quiz.creatorID != nil)

        Task {
            do {
                let published: Quiz
                if shouldUpdateRemote {
                    published = try await quizDataClient.updateQuiz(
                        quiz: quiz,
                        creatorID: session.userID,
                        accessToken: session.accessToken
                    )
                } else {
                    published = try await quizDataClient.createQuiz(
                        quiz: quiz,
                        creatorID: session.userID,
                        accessToken: session.accessToken
                    )
                }
                insertOrReplaceQuiz(published)
            } catch {
                errorMessage = "診断の保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func deleteQuiz(_ quiz: Quiz) async {
        errorMessage = nil

        if let session = authSession,
           let quizDataClient,
           quiz.creatorID != nil {
            do {
                try await quizDataClient.deleteQuiz(
                    quizID: quiz.id,
                    creatorID: session.userID,
                    accessToken: session.accessToken
                )
            } catch {
                errorMessage = "診断の削除に失敗しました: \(error.localizedDescription)"
                return
            }
        }

        removeQuizLocally(quiz)
    }

    func buildShareMessage(for result: DiagnosisResult) async {
        do {
            let shareURL = try await makeShareURL(for: result)
            let displayName = result.roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? result.resultCode : "\(result.resultCode)（\(result.roleName)）"
            let message = "私の診断結果は \(displayName) でした。あなたも回答してみてください。"
            sharePayload = SharePayload(shareURL: shareURL, message: message)
        } catch {
            errorMessage = "共有リンクの作成に失敗しました: \(error.localizedDescription)"
        }
    }

    func buildShareMessage(for quiz: Quiz) async {
        do {
            let shareURL = try await makeShareURL(for: quiz)
            let message = "この診断に回答してみてください。"
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

    private func applyDevBypassIdentityIfNeeded() {
        isAuthenticated = true
        currentUserEmail = "dev-preview@local"
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
        if let quiz = quizzes.first(where: { $0.id == result.quizID }) {
            return try await makeShareURL(for: quiz)
        }

        let accessToken = authSession?.accessToken

        if authClient != nil && (accessToken == nil || accessToken?.isEmpty == true) {
            throw APIClientError.server(statusCode: 401, message: skipLoginForDev ? "共有リンクを発行するには SKIP_LOGIN_FOR_DEV を false にしてログインしてください" : "共有にはログインが必要です")
        }

        return try await apiClient.createShareLink(quizID: result.quizID, accessToken: accessToken).shareURL
    }

    private func makeShareURL(for quiz: Quiz) async throws -> URL {
        let accessToken = authSession?.accessToken

        if authClient != nil && (accessToken == nil || accessToken?.isEmpty == true) {
            throw APIClientError.server(statusCode: 401, message: skipLoginForDev ? "共有リンクを発行するには SKIP_LOGIN_FOR_DEV を false にしてログインしてください" : "共有にはログインが必要です")
        }

        do {
            return try await apiClient.createShareLink(quizID: quiz.id, accessToken: accessToken).shareURL
        } catch {
            guard let session = authSession,
                  let quizDataClient else {
                throw error
            }

            let published: Quiz
            if quiz.creatorID != nil {
                published = try await quizDataClient.updateQuiz(
                    quiz: quiz,
                    creatorID: session.userID,
                    accessToken: session.accessToken
                )
            } else {
                do {
                    published = try await quizDataClient.createQuiz(
                        quiz: quiz,
                        creatorID: session.userID,
                        accessToken: session.accessToken
                    )
                } catch let publishError as QuizDataClientError {
                    if case .server(let statusCode, _) = publishError,
                       statusCode == 409,
                       let existing = try await quizDataClient.fetchQuiz(publicID: quiz.publicID) {
                        published = existing
                    } else {
                        throw publishError
                    }
                }
            }

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

    private func removeQuizLocally(_ quiz: Quiz) {
        quizzes.removeAll { $0.id == quiz.id || $0.publicID == quiz.publicID }

        if activeQuiz?.id == quiz.id {
            activeQuiz = nil
        }

        if latestResult?.quizID == quiz.id {
            latestResult = nil
        }

        sharePayload = nil
        activeShareToken = nil
        imageStore.removeAllImages(quizPublicID: quiz.publicID)
    }
}
