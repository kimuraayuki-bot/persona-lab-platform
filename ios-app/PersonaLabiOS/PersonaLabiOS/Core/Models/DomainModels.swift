import Foundation

public struct Quiz: Identifiable, Codable, Hashable {
    public let id: UUID
    public var publicID: String
    public var creatorID: UUID?
    public var title: String
    public var description: String
    public var visibility: Visibility
    public var questions: [Question]
    public var axisDefinitions: [AxisDefinition]
    public var resultProfiles: [QuizResultProfile]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        publicID: String,
        creatorID: UUID? = nil,
        title: String,
        description: String,
        visibility: Visibility = .linkOnly,
        questions: [Question],
        axisDefinitions: [AxisDefinition] = AxisDefinition.defaultSet(),
        resultProfiles: [QuizResultProfile] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.publicID = publicID
        self.creatorID = creatorID
        self.title = title
        self.description = description
        self.visibility = visibility
        self.questions = questions

        let normalizedAxes = AxisDefinition.normalized(axisDefinitions)
        self.axisDefinitions = normalizedAxes
        self.resultProfiles = QuizResultProfile.normalized(resultProfiles, axisDefinitions: normalizedAxes)

        self.createdAt = createdAt
    }
}

public enum Visibility: String, Codable, CaseIterable, Hashable {
    case linkOnly = "share_link"
    case directoryPublic = "directory_public"

    public var title: String {
        switch self {
        case .linkOnly:
            return "共有リンク限定"
        case .directoryPublic:
            return "ランキング掲載可"
        }
    }

    public var summary: String {
        switch self {
        case .linkOnly:
            return "作成者が発行したURLを知っている人だけが回答できます。"
        case .directoryPublic:
            return "ランキングと公開ページに表示され、token なしでも回答できます。"
        }
    }
}

public enum AxisID: String, Codable, CaseIterable, Hashable {
    case ei
    case sn
    case tf
    case jp

    public var defaultPositiveCode: String {
        switch self {
        case .ei: return "E"
        case .sn: return "S"
        case .tf: return "T"
        case .jp: return "J"
        }
    }

    public var defaultNegativeCode: String {
        switch self {
        case .ei: return "I"
        case .sn: return "N"
        case .tf: return "F"
        case .jp: return "P"
        }
    }

    public var defaultPositiveLabel: String {
        defaultPositiveCode
    }

    public var defaultNegativeLabel: String {
        defaultNegativeCode
    }

    public func axisScore(from signedValue: Int) -> AxisScore {
        switch self {
        case .ei: return AxisScore(ei: signedValue)
        case .sn: return AxisScore(sn: signedValue)
        case .tf: return AxisScore(tf: signedValue)
        case .jp: return AxisScore(jp: signedValue)
        }
    }

    public func value(from score: AxisScore) -> Int {
        switch self {
        case .ei: return score.ei
        case .sn: return score.sn
        case .tf: return score.tf
        case .jp: return score.jp
        }
    }
}

public enum TieBreakSide: String, Codable, CaseIterable, Hashable {
    case positive
    case negative
}

public struct AxisDefinition: Identifiable, Codable, Hashable {
    public var axisID: AxisID
    public var order: Int
    public var isEnabled: Bool
    public var positiveCode: String
    public var negativeCode: String
    public var positiveLabel: String
    public var negativeLabel: String
    public var tieBreak: TieBreakSide

    public var id: String { axisID.rawValue }

    public init(
        axisID: AxisID,
        order: Int,
        isEnabled: Bool = true,
        positiveCode: String,
        negativeCode: String,
        positiveLabel: String,
        negativeLabel: String,
        tieBreak: TieBreakSide = .positive
    ) {
        self.axisID = axisID
        self.order = order
        self.isEnabled = isEnabled
        self.positiveCode = Self.sanitizeCode(positiveCode, fallback: axisID.defaultPositiveCode)
        self.negativeCode = Self.sanitizeCode(negativeCode, fallback: axisID.defaultNegativeCode)
        self.positiveLabel = positiveLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? self.positiveCode
            : positiveLabel
        self.negativeLabel = negativeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? self.negativeCode
            : negativeLabel
        self.tieBreak = tieBreak
    }

    public static func `default`(for axisID: AxisID) -> AxisDefinition {
        AxisDefinition(
            axisID: axisID,
            order: AxisID.allCases.firstIndex(of: axisID) ?? 0,
            isEnabled: true,
            positiveCode: axisID.defaultPositiveCode,
            negativeCode: axisID.defaultNegativeCode,
            positiveLabel: axisID.defaultPositiveLabel,
            negativeLabel: axisID.defaultNegativeLabel,
            tieBreak: .positive
        )
    }

    public static func defaultSet() -> [AxisDefinition] {
        AxisID.allCases.map { AxisDefinition.default(for: $0) }
    }

    public static func normalized(_ axisDefinitions: [AxisDefinition]) -> [AxisDefinition] {
        var byAxis = Dictionary(uniqueKeysWithValues: axisDefinitions.map { ($0.axisID, $0) })
        for axis in AxisID.allCases where byAxis[axis] == nil {
            byAxis[axis] = .default(for: axis)
        }

        return AxisID.allCases.enumerated().compactMap { index, axis in
            guard var axisDefinition = byAxis[axis] else { return nil }
            axisDefinition.order = index
            axisDefinition.positiveCode = sanitizeCode(axisDefinition.positiveCode, fallback: axis.defaultPositiveCode)
            axisDefinition.negativeCode = sanitizeCode(axisDefinition.negativeCode, fallback: axis.defaultNegativeCode)
            if axisDefinition.positiveLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                axisDefinition.positiveLabel = axisDefinition.positiveCode
            }
            if axisDefinition.negativeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                axisDefinition.negativeLabel = axisDefinition.negativeCode
            }
            return axisDefinition
        }
    }

    public static func enabled(_ axisDefinitions: [AxisDefinition]) -> [AxisDefinition] {
        normalized(axisDefinitions)
            .filter(\.isEnabled)
            .sorted { $0.order < $1.order }
    }

    public static func sanitizeCode(_ code: String, fallback: String) -> String {
        let cleaned = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        if cleaned.isEmpty {
            return fallback
        }

        return String(cleaned.prefix(4))
    }
}

public struct QuizResultProfile: Identifiable, Codable, Hashable {
    public var resultCode: String
    public var roleName: String
    public var summary: String
    public var detail: String
    public var imageURL: String?

    public var id: String { resultCode }

    public init(
        resultCode: String,
        roleName: String,
        summary: String,
        detail: String,
        imageURL: String? = nil
    ) {
        self.resultCode = resultCode.uppercased()
        self.roleName = roleName
        self.summary = summary
        self.detail = detail
        self.imageURL = imageURL
    }

    public static func `default`(for resultCode: String) -> QuizResultProfile {
        QuizResultProfile(
            resultCode: resultCode,
            roleName: "\(resultCode.uppercased())タイプ",
            summary: "この診断で導かれた結果タイプです。",
            detail: "この説明は作成者が自由に編集できます。"
        )
    }

    public static func normalized(_ profiles: [QuizResultProfile], axisDefinitions: [AxisDefinition]) -> [QuizResultProfile] {
        let expectedCodes = ResultCodeEngine.allCodes(axisDefinitions: axisDefinitions)
        let byCode = Dictionary(uniqueKeysWithValues: profiles.map { ($0.resultCode.uppercased(), $0) })

        return expectedCodes.map { code in
            if let existing = byCode[code] {
                return QuizResultProfile(
                    resultCode: code,
                    roleName: existing.roleName,
                    summary: existing.summary,
                    detail: existing.detail,
                    imageURL: existing.imageURL
                )
            }
            return .default(for: code)
        }
    }
}

public enum ResultCodeEngine {
    public static func orderedAxisDefinitions(_ axisDefinitions: [AxisDefinition]) -> [AxisDefinition] {
        AxisDefinition.enabled(axisDefinitions)
    }

    public static func allCodes(axisDefinitions: [AxisDefinition]) -> [String] {
        let ordered = orderedAxisDefinitions(axisDefinitions)
        guard !ordered.isEmpty else { return [] }

        var results: [String] = [""]
        for axis in ordered {
            var next: [String] = []
            for prefix in results {
                next.append(prefix + axis.positiveCode)
                next.append(prefix + axis.negativeCode)
            }
            results = next
        }

        return results
    }

    public static func decode(score: AxisScore, axisDefinitions: [AxisDefinition]) -> String {
        let ordered = orderedAxisDefinitions(axisDefinitions)
        guard !ordered.isEmpty else { return "" }
        var code = ""

        for axis in ordered {
            let value = axis.axisID.value(from: score)
            if value > 0 {
                code += axis.positiveCode
            } else if value < 0 {
                code += axis.negativeCode
            } else {
                code += axis.tieBreak == .positive ? axis.positiveCode : axis.negativeCode
            }
        }

        return code
    }

    public static func profile(for resultCode: String, in profiles: [QuizResultProfile]) -> QuizResultProfile? {
        let normalized = resultCode.uppercased()
        return profiles.first { $0.resultCode.uppercased() == normalized }
    }
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
    public var resultCode: String
    public var roleName: String
    public var summary: String
    public var detail: String
    public var axisScore: AxisScore
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        quizID: UUID,
        resultCode: String,
        roleName: String = "",
        summary: String = "",
        detail: String = "",
        axisScore: AxisScore,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.quizID = quizID
        self.resultCode = resultCode.uppercased()
        self.roleName = roleName
        self.summary = summary
        self.detail = detail
        self.axisScore = axisScore
        self.createdAt = createdAt
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

public struct PublicQuizSummary: Codable, Hashable {
    public var publicID: String
    public var title: String
    public var description: String

    enum CodingKeys: String, CodingKey {
        case publicID = "public_id"
        case title
        case description
    }
}

public struct RankingResultStat: Codable, Hashable, Identifiable {
    public var resultCode: String
    public var responseCount: Int

    public var id: String { resultCode }

    enum CodingKeys: String, CodingKey {
        case resultCode = "result_code"
        case responseCount = "response_count"
    }
}

public struct PublicQuizRankingEntry: Codable, Hashable, Identifiable {
    public var rank: Int
    public var quizID: UUID
    public var totalResponses: Int
    public var updatedAt: Date?
    public var quiz: PublicQuizSummary
    public var topResults: [RankingResultStat]

    public var id: UUID { quizID }

    enum CodingKeys: String, CodingKey {
        case rank
        case quizID = "quiz_id"
        case totalResponses = "total_responses"
        case updatedAt = "updated_at"
        case quiz
        case topResults = "top_results"
    }
}

public enum QuizReportSource: String, Codable, CaseIterable, Hashable {
    case webRanking = "web_ranking"
    case webQuiz = "web_quiz"
    case iosRanking = "ios_ranking"
    case iosQuiz = "ios_quiz"
    case iosResult = "ios_result"
}

public enum QuizReportReason: String, Codable, CaseIterable, Hashable, Identifiable {
    case illegal
    case sexual
    case violent
    case harassment
    case copyright
    case spam
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .illegal:
            return "違法・犯罪"
        case .sexual:
            return "性的コンテンツ"
        case .violent:
            return "暴力・残虐"
        case .harassment:
            return "嫌がらせ・差別"
        case .copyright:
            return "著作権・権利侵害"
        case .spam:
            return "スパム・釣り"
        case .other:
            return "その他"
        }
    }
}

public struct SubmitQuizReportRequest: Codable, Hashable {
    public var quizPublicID: String
    public var source: QuizReportSource
    public var reason: QuizReportReason
    public var details: String
    public var reporterEmail: String?
    public var pageURL: String?
    public var appVersion: String?

    public init(
        quizPublicID: String,
        source: QuizReportSource,
        reason: QuizReportReason,
        details: String = "",
        reporterEmail: String? = nil,
        pageURL: String? = nil,
        appVersion: String? = nil
    ) {
        self.quizPublicID = quizPublicID
        self.source = source
        self.reason = reason
        self.details = details
        self.reporterEmail = reporterEmail
        self.pageURL = pageURL
        self.appVersion = appVersion
    }

    enum CodingKeys: String, CodingKey {
        case quizPublicID = "quiz_public_id"
        case source
        case reason
        case details
        case reporterEmail = "reporter_email"
        case pageURL = "page_url"
        case appVersion = "app_version"
    }
}
