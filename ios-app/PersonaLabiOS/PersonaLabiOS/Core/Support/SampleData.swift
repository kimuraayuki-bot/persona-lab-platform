import Foundation

public enum SampleData {
    public static let demoQuiz: Quiz = {
        let q1 = makeScaleQuestion(
            prompt: "初対面の場ではどう振る舞うことが多いですか？",
            order: 0,
            agreeText: "そう思う",
            disagreeText: "そう思わない",
            axis: .ei,
            agreeMapsToPositive: true
        )

        let q2 = makeScaleQuestion(
            prompt: "意思決定では客観的な合理性を重視する。",
            order: 1,
            agreeText: "そう思う",
            disagreeText: "そう思わない",
            axis: .tf,
            agreeMapsToPositive: true
        )

        let q3 = makeScaleQuestion(
            prompt: "予定は先に固めて進める方が落ち着く。",
            order: 2,
            agreeText: "そう思う",
            disagreeText: "そう思わない",
            axis: .jp,
            agreeMapsToPositive: true
        )

        let q4 = makeScaleQuestion(
            prompt: "情報収集では具体例より可能性を重視する。",
            order: 3,
            agreeText: "そう思う",
            disagreeText: "そう思わない",
            axis: .sn,
            agreeMapsToPositive: false
        )

        return Quiz(
            publicID: "demo-quiz",
            title: "デモ診断",
            description: "カスタム診断のサンプル",
            questions: [q1, q2, q3, q4]
        )
    }()

    private static func makeScaleQuestion(
        prompt: String,
        order: Int,
        agreeText: String,
        disagreeText: String,
        axis: AxisKind,
        agreeMapsToPositive: Bool
    ) -> Question {
        let values = [3, 2, 1, 0, -1, -2, -3]

        let choices = values.enumerated().map { index, value in
            let signedValue = agreeMapsToPositive ? value : -value
            return Choice(
                text: scaleChoiceText(index: index, agreeText: agreeText, disagreeText: disagreeText),
                order: index,
                axisDelta: axis.axisScore(from: signedValue)
            )
        }

        return Question(prompt: prompt, order: order, choices: choices)
    }

    private static func scaleChoiceText(index: Int, agreeText: String, disagreeText: String) -> String {
        switch index {
        case 0: return agreeText
        case 1: return "やや\(agreeText)"
        case 2: return "少し\(agreeText)"
        case 3: return "どちらでもない"
        case 4: return "少し\(disagreeText)"
        case 5: return "やや\(disagreeText)"
        case 6: return disagreeText
        default: return ""
        }
    }
}

private enum AxisKind {
    case ei
    case sn
    case tf
    case jp

    func axisScore(from signedValue: Int) -> AxisScore {
        switch self {
        case .ei: return AxisScore(ei: signedValue)
        case .sn: return AxisScore(sn: signedValue)
        case .tf: return AxisScore(tf: signedValue)
        case .jp: return AxisScore(jp: signedValue)
        }
    }
}
