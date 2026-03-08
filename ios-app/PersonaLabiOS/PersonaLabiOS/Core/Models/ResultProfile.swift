import Foundation

public struct ResultProfile: Codable, Hashable {
    public let type: MBTIType
    public let summary: String

    public init(type: MBTIType, summary: String) {
        self.type = type
        self.summary = summary
    }
}

public enum ResultProfileStore {
    public static let all: [MBTIType: ResultProfile] = [
        .intj: .init(type: .intj, summary: "戦略志向で計画を立てて前進するタイプ"),
        .intp: .init(type: .intp, summary: "分析力が高く概念を深掘りするタイプ"),
        .entj: .init(type: .entj, summary: "意思決定が速く目標達成を牽引するタイプ"),
        .entp: .init(type: .entp, summary: "発想が豊かで変化を楽しむタイプ"),
        .infj: .init(type: .infj, summary: "洞察力と共感力で周囲を支えるタイプ"),
        .infp: .init(type: .infp, summary: "価値観を大切にし創造性を発揮するタイプ"),
        .enfj: .init(type: .enfj, summary: "対人理解に優れ人を巻き込むタイプ"),
        .enfp: .init(type: .enfp, summary: "好奇心旺盛で可能性を広げるタイプ"),
        .istj: .init(type: .istj, summary: "誠実で着実に物事を完遂するタイプ"),
        .isfj: .init(type: .isfj, summary: "献身的で細やかな配慮が得意なタイプ"),
        .estj: .init(type: .estj, summary: "現実的で運営力に優れるタイプ"),
        .esfj: .init(type: .esfj, summary: "協調性が高く場を整えるタイプ"),
        .istp: .init(type: .istp, summary: "冷静に状況を捉え実践で解決するタイプ"),
        .isfp: .init(type: .isfp, summary: "感性豊かで柔軟に周囲と関わるタイプ"),
        .estp: .init(type: .estp, summary: "行動力が高く機会を掴むタイプ"),
        .esfp: .init(type: .esfp, summary: "明るく社交的で空気を盛り上げるタイプ")
    ]
}
