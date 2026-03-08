import Foundation

public enum ValidationError: Error, LocalizedError, Equatable {
    case emptyTitle
    case titleTooLong
    case tooManyQuestions
    case tooFewQuestions
    case emptyQuestionPrompt
    case tooManyChoices
    case tooFewChoices
    case emptyChoiceText
    case answerCountMismatch
    case duplicatedAnswer
    case invalidChoice

    public var errorDescription: String? {
        switch self {
        case .emptyTitle: return "タイトルが空です。"
        case .titleTooLong: return "タイトルが長すぎます。"
        case .tooManyQuestions: return "設問数が上限を超えています。"
        case .tooFewQuestions: return "設問数が不足しています。"
        case .emptyQuestionPrompt: return "設問文が空です。"
        case .tooManyChoices: return "選択肢数が上限を超えています。"
        case .tooFewChoices: return "選択肢数が不足しています。"
        case .emptyChoiceText: return "選択肢文が空です。"
        case .answerCountMismatch: return "回答数が設問数と一致しません。"
        case .duplicatedAnswer: return "重複回答があります。"
        case .invalidChoice: return "不正な選択肢が含まれています。"
        }
    }
}

public enum QuizValidator {
    public static let maxTitleLength = 100
    public static let minQuestions = 4
    public static let maxQuestions = 60
    public static let minChoicesPerQuestion = 2
    public static let maxChoicesPerQuestion = 8

    public static func validate(quiz: Quiz) throws {
        if quiz.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyTitle
        }
        if quiz.title.count > maxTitleLength {
            throw ValidationError.titleTooLong
        }
        if quiz.questions.count < minQuestions {
            throw ValidationError.tooFewQuestions
        }
        if quiz.questions.count > maxQuestions {
            throw ValidationError.tooManyQuestions
        }

        for question in quiz.questions {
            if question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationError.emptyQuestionPrompt
            }
            if question.choices.count < minChoicesPerQuestion {
                throw ValidationError.tooFewChoices
            }
            if question.choices.count > maxChoicesPerQuestion {
                throw ValidationError.tooManyChoices
            }
            if question.choices.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                throw ValidationError.emptyChoiceText
            }
        }
    }

    public static func validateAnswers(quiz: Quiz, answers: [ResponseAnswer]) throws -> [ResponseAnswer] {
        if answers.count != quiz.questions.count {
            throw ValidationError.answerCountMismatch
        }

        let questionIDs = Set(quiz.questions.map(\.id))
        let uniqueQuestionCount = Set(answers.map(\.questionID)).count
        if uniqueQuestionCount != answers.count {
            throw ValidationError.duplicatedAnswer
        }

        for answer in answers {
            guard questionIDs.contains(answer.questionID),
                  let question = quiz.questions.first(where: { $0.id == answer.questionID }),
                  question.choices.contains(where: { $0.id == answer.choiceID }) else {
                throw ValidationError.invalidChoice
            }
        }

        return answers
    }
}
