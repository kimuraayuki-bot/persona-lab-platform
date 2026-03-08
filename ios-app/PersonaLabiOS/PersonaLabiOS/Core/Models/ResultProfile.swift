import Foundation

public enum ResultProfileStore {
    public static func fallbackSummary(for resultCode: String) -> String {
        "\(resultCode.uppercased()) の傾向を示す結果です。"
    }

    public static func fallbackProfile(for resultCode: String) -> QuizResultProfile {
        QuizResultProfile(
            resultCode: resultCode.uppercased(),
            roleName: "\(resultCode.uppercased())タイプ",
            summary: fallbackSummary(for: resultCode),
            detail: "この説明は診断作成者が編集できます。"
        )
    }
}
