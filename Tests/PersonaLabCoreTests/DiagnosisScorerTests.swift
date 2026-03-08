import XCTest
@testable import PersonaLabCore

final class DiagnosisScorerTests: XCTestCase {
    func testCalculateResultReturnsExpectedType() throws {
        let quiz = SampleData.demoQuiz
        let answers = quiz.questions.map { question in
            ResponseAnswer(questionID: question.id, choiceID: question.choices[0].id)
        }

        let result = try DiagnosisScorer.calculateResult(quiz: quiz, answers: answers)

        XCTAssertEqual(result.type, .estj)
        XCTAssertEqual(result.axisScore, AxisScore(ei: 2, sn: 2, tf: 2, jp: 2))
    }

    func testTieBreakUsesESTJSideWhenZero() {
        let type = MBTIDecoder.decode(from: .zero)
        XCTAssertEqual(type, .estj)
    }

    func testAnswerValidationThrowsForInvalidChoice() {
        let quiz = SampleData.demoQuiz
        let invalid = quiz.questions.map { question in
            ResponseAnswer(questionID: question.id, choiceID: UUID())
        }

        XCTAssertThrowsError(try DiagnosisScorer.calculateResult(quiz: quiz, answers: invalid)) { error in
            XCTAssertEqual(error as? ValidationError, .invalidChoice)
        }
    }

    func testValidateQuizRejectsTooFewQuestions() {
        let q = Question(prompt: "Q", order: 0, choices: [
            Choice(text: "A", order: 0, axisDelta: .zero),
            Choice(text: "B", order: 1, axisDelta: .zero)
        ])
        let quiz = Quiz(publicID: "x", title: "short", description: "", questions: [q])

        XCTAssertThrowsError(try QuizValidator.validate(quiz: quiz)) { error in
            XCTAssertEqual(error as? ValidationError, .tooFewQuestions)
        }
    }
}
