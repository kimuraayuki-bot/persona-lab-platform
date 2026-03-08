import Foundation

public enum SampleData {
    public static let demoQuiz: Quiz = {
        let q1 = Question(
            prompt: "初対面の場ではどう振る舞うことが多いですか？",
            order: 0,
            choices: [
                Choice(text: "自分から話しかける", order: 0, axisDelta: AxisScore(ei: 2)),
                Choice(text: "相手から話しかけられるまで様子を見る", order: 1, axisDelta: AxisScore(ei: -2))
            ]
        )
        let q2 = Question(
            prompt: "意思決定で重視するのは？",
            order: 1,
            choices: [
                Choice(text: "客観的な合理性", order: 0, axisDelta: AxisScore(tf: 2)),
                Choice(text: "人の気持ちとの調和", order: 1, axisDelta: AxisScore(tf: -2))
            ]
        )
        let q3 = Question(
            prompt: "予定の立て方は？",
            order: 2,
            choices: [
                Choice(text: "先に決めて進めたい", order: 0, axisDelta: AxisScore(jp: 2)),
                Choice(text: "状況を見ながら柔軟に進めたい", order: 1, axisDelta: AxisScore(jp: -2))
            ]
        )
        let q4 = Question(
            prompt: "情報収集で自然なのは？",
            order: 3,
            choices: [
                Choice(text: "具体例や事実を重視する", order: 0, axisDelta: AxisScore(sn: 2)),
                Choice(text: "全体像や可能性を重視する", order: 1, axisDelta: AxisScore(sn: -2))
            ]
        )

        return Quiz(
            publicID: "demo-quiz",
            title: "デモ診断",
            description: "16タイプ診断のサンプル",
            questions: [q1, q2, q3, q4]
        )
    }()
}
