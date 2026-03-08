import SwiftUI
import PersonaLabCore

struct QuizTakingView: View {
    @EnvironmentObject private var state: AppState
    let quiz: Quiz

    @State private var currentIndex = 0
    @State private var selected: [UUID: UUID] = [:]
    @State private var isSubmitting = false

    private var currentQuestion: Question? {
        guard quiz.questions.indices.contains(currentIndex) else { return nil }
        return quiz.questions[currentIndex]
    }

    var body: some View {
        VStack {
            if let question = currentQuestion {
                questionContent(question)
            } else {
                ContentUnavailableView("設問がありません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(quiz.title)
        .navigationDestination(isPresented: Binding(
            get: { state.latestResult != nil },
            set: { if !$0 { state.latestResult = nil } }
        )) {
            if let result = state.latestResult {
                ResultView(result: result)
            }
        }
    }

    @ViewBuilder
    private func questionContent(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(value: Double(currentIndex + 1), total: Double(quiz.questions.count))
            Text(question.prompt)
                .font(.title3.bold())

            ForEach(question.choices) { choice in
                Button {
                    selected[question.id] = choice.id
                } label: {
                    HStack {
                        Image(systemName: selected[question.id] == choice.id ? "largecircle.fill.circle" : "circle")
                        Text(choice.text)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(10)
                .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            Button(currentIndex == quiz.questions.count - 1 ? "結果を見る" : "次へ") {
                onNext(question: question)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected[question.id] == nil || isSubmitting)
        }
        .padding()
    }

    private func onNext(question: Question) {
        guard selected[question.id] != nil else { return }
        if currentIndex < quiz.questions.count - 1 {
            currentIndex += 1
            return
        }

        isSubmitting = true

        let answers = quiz.questions.compactMap { q -> ResponseAnswer? in
            guard let choiceID = selected[q.id] else { return nil }
            return ResponseAnswer(questionID: q.id, choiceID: choiceID)
        }

        Task {
            defer { isSubmitting = false }
            do {
                if let token = state.activeShareToken {
                    let payload = SubmitResponseRequest(
                        quizPublicID: quiz.publicID,
                        token: token,
                        answers: answers
                    )
                    let submitted = try await state.apiClient.submitResponse(payload: payload)
                    let parsedType = MBTIType(canonicalValue: submitted.mbtiType) ?? .estj
                    state.latestResult = DiagnosisResult(
                        id: submitted.resultID,
                        quizID: quiz.id,
                        type: parsedType,
                        axisScore: submitted.axisScores
                    )
                } else {
                    state.latestResult = try DiagnosisScorer.calculateResult(quiz: quiz, answers: answers)
                }
            } catch {
                state.errorMessage = error.localizedDescription
            }
        }
    }
}
