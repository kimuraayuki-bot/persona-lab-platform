import SwiftUI
import PersonaLabCore

struct QuizEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: AppState

    @State private var title = ""
    @State private var description = ""
    @State private var questions: [QuestionDraft] = [QuestionDraft.sample(index: 0)]

    var onSave: (Quiz) -> Void

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("タイトル", text: $title)
                TextField("説明", text: $description, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("設問") {
                ForEach($questions) { $question in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("質問文", text: $question.prompt)
                        ForEach($question.choices) { $choice in
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("選択肢", text: $choice.text)
                                HStack {
                                    Stepper("EI: \(choice.ei)", value: $choice.ei, in: -3...3)
                                    Stepper("SN: \(choice.sn)", value: $choice.sn, in: -3...3)
                                }
                                HStack {
                                    Stepper("TF: \(choice.tf)", value: $choice.tf, in: -3...3)
                                    Stepper("JP: \(choice.jp)", value: $choice.jp, in: -3...3)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        Button("選択肢を追加") {
                            question.choices.append(.sample(index: question.choices.count))
                        }
                    }
                }
                Button("設問を追加") {
                    questions.append(.sample(index: questions.count))
                }
            }
        }
        .navigationTitle("診断作成")
        .toolbar {
            ToolbarItem {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem {
                Button("保存") {
                    saveQuiz()
                }
            }
        }
    }

    private func saveQuiz() {
        let mappedQuestions = questions.enumerated().map { index, q in
            Question(
                prompt: q.prompt,
                order: index,
                choices: q.choices.enumerated().map { cIndex, c in
                    Choice(
                        text: c.text,
                        order: cIndex,
                        axisDelta: AxisScore(ei: c.ei, sn: c.sn, tf: c.tf, jp: c.jp)
                    )
                }
            )
        }

        let quiz = Quiz(
            publicID: UUID().uuidString.lowercased(),
            title: title,
            description: description,
            questions: mappedQuestions
        )

        do {
            try QuizValidator.validate(quiz: quiz)
            onSave(quiz)
            dismiss()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}

struct QuestionDraft: Identifiable {
    let id = UUID()
    var prompt: String
    var choices: [ChoiceDraft]

    static func sample(index: Int) -> QuestionDraft {
        QuestionDraft(
            prompt: "質問\(index + 1)",
            choices: [.sample(index: 0), .sample(index: 1)]
        )
    }
}

struct ChoiceDraft: Identifiable {
    let id = UUID()
    var text: String
    var ei: Int
    var sn: Int
    var tf: Int
    var jp: Int

    static func sample(index: Int) -> ChoiceDraft {
        ChoiceDraft(text: "選択肢\(index + 1)", ei: 0, sn: 0, tf: 0, jp: 0)
    }
}
