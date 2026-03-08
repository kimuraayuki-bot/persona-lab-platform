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

        let resultCode = ResultCodeEngine.decode(score: total, axisDefinitions: quiz.axisDefinitions)
        let profile = ResultCodeEngine.profile(for: resultCode, in: quiz.resultProfiles) ?? .default(for: resultCode)

        return DiagnosisResult(
            quizID: quiz.id,
            resultCode: resultCode,
            roleName: profile.roleName,
            summary: profile.summary,
            detail: profile.detail,
            axisScore: total
        )
    }
}
