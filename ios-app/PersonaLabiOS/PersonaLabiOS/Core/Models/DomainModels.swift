import Foundation

public struct Quiz: Identifiable, Codable, Hashable {
    public let id: UUID
    public var publicID: String
    public var creatorID: UUID?
    public var title: String
    public var description: String
    public var visibility: Visibility
    public var questions: [Question]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        publicID: String,
        creatorID: UUID? = nil,
        title: String,
        description: String,
        visibility: Visibility = .linkOnly,
        questions: [Question],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.publicID = publicID
        self.creatorID = creatorID
        self.title = title
        self.description = description
        self.visibility = visibility
        self.questions = questions
        self.createdAt = createdAt
    }
}

public enum Visibility: String, Codable, CaseIterable, Hashable {
    case linkOnly = "link_only"
}

public struct Question: Identifiable, Codable, Hashable {
    public let id: UUID
    public var prompt: String
    public var order: Int
    public var choices: [Choice]

    public init(id: UUID = UUID(), prompt: String, order: Int, choices: [Choice]) {
        self.id = id
        self.prompt = prompt
        self.order = order
        self.choices = choices
    }
}

public struct Choice: Identifiable, Codable, Hashable {
    public let id: UUID
    public var text: String
    public var order: Int
    public var axisDelta: AxisScore

    public init(id: UUID = UUID(), text: String, order: Int, axisDelta: AxisScore) {
        self.id = id
        self.text = text
        self.order = order
        self.axisDelta = axisDelta
    }
}

public struct AxisScore: Codable, Hashable {
    public var ei: Int
    public var sn: Int
    public var tf: Int
    public var jp: Int

    public init(ei: Int = 0, sn: Int = 0, tf: Int = 0, jp: Int = 0) {
        self.ei = ei
        self.sn = sn
        self.tf = tf
        self.jp = jp
    }

    public static let zero = AxisScore()

    public static func + (lhs: AxisScore, rhs: AxisScore) -> AxisScore {
        AxisScore(
            ei: lhs.ei + rhs.ei,
            sn: lhs.sn + rhs.sn,
            tf: lhs.tf + rhs.tf,
            jp: lhs.jp + rhs.jp
        )
    }
}

public struct ResponseAnswer: Codable, Hashable {
    public var questionID: UUID
    public var choiceID: UUID

    enum CodingKeys: String, CodingKey {
        case questionID = "question_id"
        case choiceID = "choice_id"
    }

    public init(questionID: UUID, choiceID: UUID) {
        self.questionID = questionID
        self.choiceID = choiceID
    }
}

public struct DiagnosisResult: Identifiable, Codable, Hashable {
    public let id: UUID
    public var quizID: UUID
    public var type: MBTIType
    public var axisScore: AxisScore
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        quizID: UUID,
        type: MBTIType,
        axisScore: AxisScore,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.quizID = quizID
        self.type = type
        self.axisScore = axisScore
        self.createdAt = createdAt
    }
}

public enum MBTIType: String, Codable, CaseIterable, Hashable {
    case intj, intp, entj, entp
    case infj, infp, enfj, enfp
    case istj, isfj, estj, esfj
    case istp, isfp, estp, esfp

    public var title: String {
        rawValue.uppercased()
    }

    public init?(canonicalValue: String) {
        self.init(rawValue: canonicalValue.lowercased())
    }
}

public struct SharePayload: Codable, Hashable {
    public var shareURL: URL
    public var message: String

    public init(shareURL: URL, message: String) {
        self.shareURL = shareURL
        self.message = message
    }
}
