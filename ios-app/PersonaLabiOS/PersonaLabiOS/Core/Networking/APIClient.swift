import Foundation

public struct CreateShareLinkRequest: Codable {
    public var quizID: UUID

    enum CodingKeys: String, CodingKey {
        case quizID = "quiz_id"
    }
}

public struct CreateShareLinkResponse: Codable {
    public var shareURL: URL
    public var expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case shareURL = "share_url"
        case expiresAt = "expires_at"
    }
}

public struct SubmitResponseRequest: Codable {
    public var quizPublicID: String
    public var token: String?
    public var answers: [ResponseAnswer]

    public init(quizPublicID: String, token: String? = nil, answers: [ResponseAnswer]) {
        self.quizPublicID = quizPublicID
        self.token = token
        self.answers = answers
    }

    enum CodingKeys: String, CodingKey {
        case quizPublicID = "quiz_public_id"
        case token
        case answers
    }
}

public struct SubmitResponseResponse: Decodable {
    public var resultID: UUID
    public var resultCode: String
    public var axisScores: AxisScore
    public var roleName: String
    public var summary: String
    public var detail: String

    enum CodingKeys: String, CodingKey {
        case resultID = "result_id"
        case resultCode = "result_code"
        case mbtiType = "mbti_type"
        case axisScores = "axis_scores"
        case roleName = "role_name"
        case summary
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resultID = try container.decode(UUID.self, forKey: .resultID)

        let code = try container.decodeIfPresent(String.self, forKey: .resultCode)
            ?? container.decodeIfPresent(String.self, forKey: .mbtiType)
            ?? ""
        resultCode = code.uppercased()

        axisScores = try container.decodeIfPresent(AxisScore.self, forKey: .axisScores) ?? .zero
        roleName = try container.decodeIfPresent(String.self, forKey: .roleName) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
    }
}

private struct FetchQuizRankingResponse: Decodable {
    let ranking: [PublicQuizRankingEntry]
}

private struct SubmitQuizReportResponse: Decodable {
    let ok: Bool
}

public struct AppConfig {
    public var apiBaseURL: URL
    public var restBaseURL: URL
    public var authBaseURL: URL
    public var appDomain: URL
    public var anonKey: String

    public init(
        apiBaseURL: URL = URL(string: "https://YOUR-PROJECT.supabase.co/functions/v1")!,
        restBaseURL: URL = URL(string: "https://YOUR-PROJECT.supabase.co/rest/v1")!,
        authBaseURL: URL = URL(string: "https://YOUR-PROJECT.supabase.co/auth/v1")!,
        appDomain: URL = URL(string: "https://example.com")!,
        anonKey: String = ""
    ) {
        self.apiBaseURL = apiBaseURL
        self.restBaseURL = restBaseURL
        self.authBaseURL = authBaseURL
        self.appDomain = appDomain
        self.anonKey = anonKey
    }

    public init(projectRef: String, anonKey: String, appDomain: URL) {
        self.init(
            apiBaseURL: URL(string: "https://\(projectRef).supabase.co/functions/v1")!,
            restBaseURL: URL(string: "https://\(projectRef).supabase.co/rest/v1")!,
            authBaseURL: URL(string: "https://\(projectRef).supabase.co/auth/v1")!,
            appDomain: appDomain,
            anonKey: anonKey
        )
    }
}

public protocol APIClientProtocol {
    func createShareLink(quizID: UUID, accessToken: String?) async throws -> CreateShareLinkResponse
    func submitResponse(payload: SubmitResponseRequest) async throws -> SubmitResponseResponse
    func fetchQuizRanking(limit: Int) async throws -> [PublicQuizRankingEntry]
    func submitQuizReport(payload: SubmitQuizReportRequest) async throws
}

public enum APIClientError: Error, LocalizedError {
    case server(statusCode: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case let .server(statusCode, message):
            return "APIエラー(\(statusCode)): \(message)"
        case .invalidResponse:
            return "APIレスポンスの形式が不正です。"
        }
    }
}

public final class APIClient: APIClientProtocol {
    private let config: AppConfig
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(config: AppConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func createShareLink(quizID: UUID, accessToken: String?) async throws -> CreateShareLinkResponse {
        let endpoint = config.apiBaseURL.appending(path: "create_share_link")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken)
        request.httpBody = try encoder.encode(CreateShareLinkRequest(quizID: quizID))

        let (data, response) = try await session.data(for: request)
        try Self.ensureOK(data: data, response: response)
        return try decoder.decode(CreateShareLinkResponse.self, from: data)
    }

    public func submitResponse(payload: SubmitResponseRequest) async throws -> SubmitResponseResponse {
        let endpoint = config.apiBaseURL.appending(path: "submit_response")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: nil)
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try Self.ensureOK(data: data, response: response)
        return try decoder.decode(SubmitResponseResponse.self, from: data)
    }

    public func fetchQuizRanking(limit: Int) async throws -> [PublicQuizRankingEntry] {
        let endpoint = config.apiBaseURL.appending(path: "fetch_quiz_ranking")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: nil)
        request.httpBody = try encoder.encode(["limit": max(1, min(limit, 50))])

        let (data, response) = try await session.data(for: request)
        try Self.ensureOK(data: data, response: response)
        return try decoder.decode(FetchQuizRankingResponse.self, from: data).ranking
    }

    public func submitQuizReport(payload: SubmitQuizReportRequest) async throws {
        let endpoint = config.apiBaseURL.appending(path: "submit_report")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: nil)
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try Self.ensureOK(data: data, response: response)
        _ = try decoder.decode(SubmitQuizReportResponse.self, from: data)
    }

    private func applyAuthHeaders(to request: inout URLRequest, accessToken: String?) {
        if !config.anonKey.isEmpty {
            request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        }

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else if !config.anonKey.isEmpty {
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }
    }

    private static func ensureOK(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? "unknown error"
            throw APIClientError.server(statusCode: http.statusCode, message: message)
        }
    }
}

public final class MockAPIClient: APIClientProtocol {
    private let config: AppConfig

    public init(config: AppConfig = AppConfig()) {
        self.config = config
    }

    public func createShareLink(quizID: UUID, accessToken: String?) async throws -> CreateShareLinkResponse {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let url = config.appDomain
            .appending(path: "q")
            .appending(path: quizID.uuidString.lowercased())
            .appending(queryItems: [URLQueryItem(name: "token", value: token)])

        return CreateShareLinkResponse(
            shareURL: url,
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
    }

    public func submitResponse(payload: SubmitResponseRequest) async throws -> SubmitResponseResponse {
        let syntheticScore = AxisScore(
            ei: Int.random(in: -12...12),
            sn: Int.random(in: -12...12),
            tf: Int.random(in: -12...12),
            jp: Int.random(in: -12...12)
        )

        let axisDefinitions = AxisDefinition.defaultSet()
        let code = ResultCodeEngine.decode(score: syntheticScore, axisDefinitions: axisDefinitions)
        let profile = QuizResultProfile.default(for: code)

        let json: [String: Any] = [
            "result_id": UUID().uuidString.lowercased(),
            "result_code": code,
            "axis_scores": [
                "ei": syntheticScore.ei,
                "sn": syntheticScore.sn,
                "tf": syntheticScore.tf,
                "jp": syntheticScore.jp
            ],
            "role_name": profile.roleName,
            "summary": profile.summary,
            "detail": profile.detail
        ]

        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SubmitResponseResponse.self, from: data)
    }

    public func fetchQuizRanking(limit: Int) async throws -> [PublicQuizRankingEntry] {
        let topResults = [
            RankingResultStat(resultCode: "ENFP", responseCount: 14),
            RankingResultStat(resultCode: "INTJ", responseCount: 11),
            RankingResultStat(resultCode: "ISFJ", responseCount: 7)
        ]

        return [
            PublicQuizRankingEntry(
                rank: 1,
                quizID: SampleData.demoQuiz.id,
                totalResponses: 32,
                updatedAt: Date(),
                quiz: PublicQuizSummary(
                    publicID: SampleData.demoQuiz.publicID,
                    title: "みんなのデモ診断",
                    description: "公開ランキングのサンプルです。"
                ),
                topResults: topResults
            )
        ]
    }

    public func submitQuizReport(payload: SubmitQuizReportRequest) async throws {}
}
