import Foundation

public struct AuthSession: Codable, Hashable {
    public let accessToken: String
    public let refreshToken: String
    public let userID: UUID
    public let email: String?

    public init(accessToken: String, refreshToken: String, userID: UUID, email: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
        self.email = email
    }
}

public protocol AuthClientProtocol {
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(email: String, password: String) async throws -> AuthSession?
}

public enum AuthClientError: Error, LocalizedError {
    case server(statusCode: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case let .server(statusCode, message):
            return "認証エラー(\(statusCode)): \(message)"
        case .invalidResponse:
            return "認証レスポンスが不正です。"
        }
    }
}

public final class SupabaseAuthClient: AuthClientProtocol {
    private let config: AppConfig
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(config: AppConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        let endpoint = config.authBaseURL
            .appending(path: "token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "password")])

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request)

        let payload = EmailPasswordPayload(email: email, password: password)
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try Self.ensureOK(data: data, response: response)

        let decoded = try decoder.decode(SignInResponse.self, from: data)
        return AuthSession(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            userID: decoded.user.id,
            email: decoded.user.email
        )
    }

    public func signUp(email: String, password: String) async throws -> AuthSession? {
        let endpoint = config.authBaseURL
            .appending(path: "signup")
            .appending(queryItems: [
                URLQueryItem(name: "redirect_to", value: config.authConfirmationURL.absoluteString)
            ])

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request)

        let payload = EmailPasswordPayload(email: email, password: password)
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try Self.ensureOK(data: data, response: response)

        let decoded = try decoder.decode(SignUpResponse.self, from: data)
        guard
            let accessToken = decoded.accessToken,
            let refreshToken = decoded.refreshToken,
            let userID = decoded.user?.id
        else {
            // Email confirmation required: session is not issued yet.
            return nil
        }

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            email: decoded.user?.email
        )
    }

    private func applyAuthHeaders(to request: inout URLRequest) {
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
    }

    private static func ensureOK(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AuthClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
                ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? "unknown error"
            throw AuthClientError.server(statusCode: http.statusCode, message: message)
        }
    }
}

private struct EmailPasswordPayload: Codable {
    let email: String
    let password: String
}

private struct SignInResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct SignUpResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct AuthUser: Codable {
    let id: UUID
    let email: String?
}
