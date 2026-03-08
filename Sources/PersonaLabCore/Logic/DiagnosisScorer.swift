import Foundation

public enum DiagnosisScorer {
    public static func calculateResult(quiz: Quiz, answers: [ResponseAnswer]) throws -> DiagnosisResult {
        let validated = try QuizValidator.validateAnswers(quiz: quiz, answers: answers)

        let answerByQuestion = Dictionary(uniqueKeysWithValues: validated.map { ($0.questionID, $0.choiceID) })

        let total = quiz.questions.reduce(AxisScore.zero) { partial, question in
            guard let choiceID = answerByQuestion[question.id],
                  let choice = question.choices.first(where: { $0.id == choiceID }) else {
                return partial
            }
            return partial + choice.axisDelta
        }

        let type = MBTIDecoder.decode(from: total)
        return DiagnosisResult(quizID: quiz.id, type: type, axisScore: total)
    }
}

public enum MBTIDecoder {
    public static func decode(from score: AxisScore) -> MBTIType {
        let e = score.ei >= 0
        let s = score.sn >= 0
        let t = score.tf >= 0
        let j = score.jp >= 0

        // Tie-break is fixed to E/S/T/J side when score == 0.
        switch (e, s, t, j) {
        case (true, true, true, true): return .estj
        case (true, true, true, false): return .estp
        case (true, true, false, true): return .esfj
        case (true, true, false, false): return .esfp
        case (true, false, true, true): return .entj
        case (true, false, true, false): return .entp
        case (true, false, false, true): return .enfj
        case (true, false, false, false): return .enfp
        case (false, true, true, true): return .istj
        case (false, true, true, false): return .istp
        case (false, true, false, true): return .isfj
        case (false, true, false, false): return .isfp
        case (false, false, true, true): return .intj
        case (false, false, true, false): return .intp
        case (false, false, false, true): return .infj
        case (false, false, false, false): return .infp
        }
    }
}
