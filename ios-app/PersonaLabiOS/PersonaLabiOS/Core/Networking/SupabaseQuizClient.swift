import Foundation

public protocol QuizDataClientProtocol {
    func createQuiz(quiz: Quiz, creatorID: UUID, accessToken: String) async throws -> Quiz
    func updateQuiz(quiz: Quiz, creatorID: UUID, accessToken: String) async throws -> Quiz
    func listCreatorQuizzes(creatorID: UUID, accessToken: String) async throws -> [Quiz]
    func fetchQuiz(publicID: String) async throws -> Quiz?
}

public enum QuizDataClientError: Error, LocalizedError {
    case server(statusCode: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case let .server(statusCode, message):
            return "診断APIエラー(\(statusCode)): \(message)"
        case .invalidResponse:
            return "診断APIレスポンスが不正です。"
        }
    }
}

public final class SupabaseQuizClient: QuizDataClientProtocol {
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

    public func createQuiz(quiz: Quiz, creatorID: UUID, accessToken: String) async throws -> Quiz {
        try QuizValidator.validate(quiz: quiz)

        let createQuizRow = CreateQuizRow(
            publicID: quiz.publicID,
            creatorID: creatorID,
            title: quiz.title,
            description: quiz.description,
            visibility: quiz.visibility.rawValue
        )

        let quizRows: [QuizRow] = try await send(
            path: "quizzes",
            method: "POST",
            queryItems: nil,
            body: [createQuizRow],
            accessToken: accessToken,
            preferRepresentation: true
        )

        guard let createdQuiz = quizRows.first else {
            throw QuizDataClientError.invalidResponse
        }

        let createdQuestions = try await replaceQuestions(
            for: createdQuiz.id,
            questions: quiz.questions,
            accessToken: accessToken
        )

        return Quiz(
            id: createdQuiz.id,
            publicID: createdQuiz.publicID,
            creatorID: createdQuiz.creatorID,
            title: createdQuiz.title,
            description: createdQuiz.description,
            visibility: Visibility(rawValue: createdQuiz.visibility) ?? .linkOnly,
            questions: createdQuestions,
            createdAt: createdQuiz.createdAt
        )
    }

    public func updateQuiz(quiz: Quiz, creatorID: UUID, accessToken: String) async throws -> Quiz {
        try QuizValidator.validate(quiz: quiz)

        let queryItems = [
            URLQueryItem(name: "id", value: "eq.\(quiz.id.uuidString.lowercased())"),
            URLQueryItem(name: "creator_id", value: "eq.\(creatorID.uuidString.lowercased())")
        ]

        let updatedRows: [QuizRow] = try await send(
            path: "quizzes",
            method: "PATCH",
            queryItems: queryItems,
            body: UpdateQuizRow(
                title: quiz.title,
                description: quiz.description,
                visibility: quiz.visibility.rawValue
            ),
            accessToken: accessToken,
            preferRepresentation: true
        )

        guard let updatedQuiz = updatedRows.first else {
            throw QuizDataClientError.invalidResponse
        }

        try await sendNoResponse(
            path: "questions",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "quiz_id", value: "eq.\(quiz.id.uuidString.lowercased())")],
            body: Optional<Int>.none,
            accessToken: accessToken,
            preferRepresentation: false
        )

        let recreatedQuestions = try await replaceQuestions(
            for: updatedQuiz.id,
            questions: quiz.questions,
            accessToken: accessToken
        )

        return Quiz(
            id: updatedQuiz.id,
            publicID: updatedQuiz.publicID,
            creatorID: updatedQuiz.creatorID,
            title: updatedQuiz.title,
            description: updatedQuiz.description,
            visibility: Visibility(rawValue: updatedQuiz.visibility) ?? .linkOnly,
            questions: recreatedQuestions,
            createdAt: updatedQuiz.createdAt
        )
    }

    public func listCreatorQuizzes(creatorID: UUID, accessToken: String) async throws -> [Quiz] {
        let select = "id,public_id,creator_id,title,description,visibility,created_at,questions(id,prompt,order_index,choices(id,body,order_index,ei_delta,sn_delta,tf_delta,jp_delta))"
        let queryItems = [
            URLQueryItem(name: "select", value: select),
            URLQueryItem(name: "creator_id", value: "eq.\(creatorID.uuidString.lowercased())"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        let rows: [QuizRow] = try await send(
            path: "quizzes",
            method: "GET",
            queryItems: queryItems,
            body: Optional<Int>.none,
            accessToken: accessToken,
            preferRepresentation: false
        )

        return rows.map(Self.mapQuizRow)
    }

    public func fetchQuiz(publicID: String) async throws -> Quiz? {
        let select = "id,public_id,creator_id,title,description,visibility,created_at,questions(id,prompt,order_index,choices(id,body,order_index,ei_delta,sn_delta,tf_delta,jp_delta))"
        let queryItems = [
            URLQueryItem(name: "select", value: select),
            URLQueryItem(name: "public_id", value: "eq.\(publicID)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        let rows: [QuizRow] = try await send(
            path: "quizzes",
            method: "GET",
            queryItems: queryItems,
            body: Optional<Int>.none,
            accessToken: nil,
            preferRepresentation: false
        )

        return rows.first.map(Self.mapQuizRow)
    }

    private func replaceQuestions(
        for quizID: UUID,
        questions: [Question],
        accessToken: String
    ) async throws -> [Question] {
        var createdQuestions: [Question] = []

        for question in questions.sorted(by: { $0.order < $1.order }) {
            let questionRows: [QuestionRow] = try await send(
                path: "questions",
                method: "POST",
                queryItems: nil,
                body: [CreateQuestionRow(quizID: quizID, prompt: question.prompt, orderIndex: question.order)],
                accessToken: accessToken,
                preferRepresentation: true
            )

            guard let createdQuestion = questionRows.first else {
                throw QuizDataClientError.invalidResponse
            }

            let choicePayload = question.choices.sorted(by: { $0.order < $1.order }).map {
                CreateChoiceRow(
                    questionID: createdQuestion.id,
                    body: $0.text,
                    orderIndex: $0.order,
                    eiDelta: $0.axisDelta.ei,
                    snDelta: $0.axisDelta.sn,
                    tfDelta: $0.axisDelta.tf,
                    jpDelta: $0.axisDelta.jp
                )
            }

            let choiceRows: [ChoiceRow] = try await send(
                path: "choices",
                method: "POST",
                queryItems: nil,
                body: choicePayload,
                accessToken: accessToken,
                preferRepresentation: true
            )

            let mappedChoices = choiceRows
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .map {
                    Choice(
                        id: $0.id,
                        text: $0.body,
                        order: $0.orderIndex,
                        axisDelta: AxisScore(ei: $0.eiDelta, sn: $0.snDelta, tf: $0.tfDelta, jp: $0.jpDelta)
                    )
                }

            createdQuestions.append(
                Question(
                    id: createdQuestion.id,
                    prompt: createdQuestion.prompt,
                    order: createdQuestion.orderIndex,
                    choices: mappedChoices
                )
            )
        }

        return createdQuestions.sorted(by: { $0.order < $1.order })
    }

    private func send<Request: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem]?,
        body: Request?,
        accessToken: String?,
        preferRepresentation: Bool
    ) async throws -> Response {
        var url = config.restBaseURL.appending(path: path)
        if let queryItems, !queryItems.isEmpty {
            url = url.appending(queryItems: queryItems)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        try Self.ensureOK(data: data, response: response)
        return try decoder.decode(Response.self, from: data)
    }

    private func sendNoResponse<Request: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem]?,
        body: Request?,
        accessToken: String?,
        preferRepresentation: Bool
    ) async throws {
        var url = config.restBaseURL.appending(path: path)
        if let queryItems, !queryItems.isEmpty {
            url = url.appending(queryItems: queryItems)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        try Self.ensureOK(data: data, response: response)
    }

    private static func ensureOK(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw QuizDataClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? "unknown error"
            throw QuizDataClientError.server(statusCode: http.statusCode, message: message)
        }
    }

    private static func mapQuizRow(_ row: QuizRow) -> Quiz {
        let questions = (row.questions ?? [])
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .map { q in
                let choices = (q.choices ?? [])
                    .sorted(by: { $0.orderIndex < $1.orderIndex })
                    .map { c in
                        Choice(
                            id: c.id,
                            text: c.body,
                            order: c.orderIndex,
                            axisDelta: AxisScore(ei: c.eiDelta, sn: c.snDelta, tf: c.tfDelta, jp: c.jpDelta)
                        )
                    }

                return Question(id: q.id, prompt: q.prompt, order: q.orderIndex, choices: choices)
            }

        return Quiz(
            id: row.id,
            publicID: row.publicID,
            creatorID: row.creatorID,
            title: row.title,
            description: row.description,
            visibility: Visibility(rawValue: row.visibility) ?? .linkOnly,
            questions: questions,
            createdAt: row.createdAt
        )
    }
}

private struct CreateQuizRow: Codable {
    let publicID: String
    let creatorID: UUID
    let title: String
    let description: String
    let visibility: String

    enum CodingKeys: String, CodingKey {
        case publicID = "public_id"
        case creatorID = "creator_id"
        case title
        case description
        case visibility
    }
}

private struct UpdateQuizRow: Codable {
    let title: String
    let description: String
    let visibility: String

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case visibility
    }
}

private struct CreateQuestionRow: Codable {
    let quizID: UUID
    let prompt: String
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case quizID = "quiz_id"
        case prompt
        case orderIndex = "order_index"
    }
}

private struct CreateChoiceRow: Codable {
    let questionID: UUID
    let body: String
    let orderIndex: Int
    let eiDelta: Int
    let snDelta: Int
    let tfDelta: Int
    let jpDelta: Int

    enum CodingKeys: String, CodingKey {
        case questionID = "question_id"
        case body
        case orderIndex = "order_index"
        case eiDelta = "ei_delta"
        case snDelta = "sn_delta"
        case tfDelta = "tf_delta"
        case jpDelta = "jp_delta"
    }
}

private struct QuizRow: Codable {
    let id: UUID
    let publicID: String
    let creatorID: UUID?
    let title: String
    let description: String
    let visibility: String
    let createdAt: Date
    let questions: [QuestionRow]?

    enum CodingKeys: String, CodingKey {
        case id
        case publicID = "public_id"
        case creatorID = "creator_id"
        case title
        case description
        case visibility
        case createdAt = "created_at"
        case questions
    }
}

private struct QuestionRow: Codable {
    let id: UUID
    let prompt: String
    let orderIndex: Int
    let choices: [ChoiceRow]?

    enum CodingKeys: String, CodingKey {
        case id
        case prompt
        case orderIndex = "order_index"
        case choices
    }
}

private struct ChoiceRow: Codable {
    let id: UUID
    let body: String
    let orderIndex: Int
    let eiDelta: Int
    let snDelta: Int
    let tfDelta: Int
    let jpDelta: Int

    enum CodingKeys: String, CodingKey {
        case id
        case body
        case orderIndex = "order_index"
        case eiDelta = "ei_delta"
        case snDelta = "sn_delta"
        case tfDelta = "tf_delta"
        case jpDelta = "jp_delta"
    }
}
