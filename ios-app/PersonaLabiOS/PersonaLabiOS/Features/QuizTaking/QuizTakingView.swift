import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

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

    private var progressText: String {
        "\(currentIndex + 1) / \(max(quiz.questions.count, 1))"
    }

    var body: some View {
        ZStack {
            PopBackdrop().ignoresSafeArea()

            if let question = currentQuestion {
                VStack(spacing: 14) {
                    headerView
                    promptView(question)

                    if shouldUseScaleStyle(question: question) {
                        scaleChoiceView(question)
                    } else {
                        listChoiceView(question)
                    }

                    actionBar(question)
                }
                .padding(16)
                .allowsHitTesting(!isSubmitting)
            } else {
                ContentUnavailableView("設問がありません", systemImage: "exclamationmark.triangle")
            }

            if isSubmitting {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                ProgressView("結果を作成中...")
                    .font(.headline)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .navigationTitle(quiz.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(
            get: { state.latestResult != nil },
            set: { if !$0 { state.latestResult = nil } }
        )) {
            if let result = state.latestResult {
                ResultView(result: result)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("設問", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(PopTheme.accent)

                Spacer()

                Text(progressText)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(currentIndex + 1), total: Double(max(quiz.questions.count, 1)))
                .tint(PopTheme.accentAlt)
        }
        .popCard(cornerRadius: 16, padding: 14)
    }

    private func promptView(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("次の文について、あなたに近い方を選んでください")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(question.prompt)
                .font(.title3.bold())
                .foregroundStyle(PopTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard()
    }

    private func shouldUseScaleStyle(question: Question) -> Bool {
        question.choices.count == 7
    }

    private func scaleChoiceView(_ question: Question) -> some View {
        let sortedChoices = question.choices.sorted(by: { $0.order < $1.order })

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(sortedChoices.first?.text ?? "そう思う")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(sortedChoices.last?.text ?? "そう思わない")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 10) {
                ForEach(Array(sortedChoices.enumerated()), id: \.element.id) { index, choice in
                    let isSelected = selected[question.id] == choice.id

                    Button {
                        selected[question.id] = choice.id
                    } label: {
                        Circle()
                            .fill(bubbleColor(index: index, total: sortedChoices.count).opacity(isSelected ? 1.0 : 0.35))
                            .frame(width: bubbleSize(index: index, total: sortedChoices.count), height: bubbleSize(index: index, total: sortedChoices.count))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(isSelected ? 0.95 : 0.55), lineWidth: isSelected ? 3 : 1)
                            }
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(scaleSelectionSummary(index: index))
                }
            }
            .frame(maxWidth: .infinity)

            Text(selectedScaleText(question) ?? "丸をタップして選択")
                .font(.footnote)
                .foregroundStyle(selectedScaleText(question) == nil ? .secondary : PopTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .popCard(cornerRadius: 20)
    }

    private func listChoiceView(_ question: Question) -> some View {
        VStack(spacing: 10) {
            ForEach(question.choices.sorted(by: { $0.order < $1.order })) { choice in
                let isSelected = selected[question.id] == choice.id

                Button {
                    selected[question.id] = choice.id
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? PopTheme.accentAlt : .secondary)
                        Text(choice.text)
                            .foregroundStyle(PopTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? PopTheme.accentAlt.opacity(0.14) : Color.white.opacity(0.85))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .popCard(cornerRadius: 20)
    }

    private func actionBar(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button("戻る") {
                    guard currentIndex > 0 else { return }
                    currentIndex -= 1
                }
                .buttonStyle(.bordered)
                .disabled(currentIndex == 0 || isSubmitting)

                Spacer()

                Button(currentIndex == quiz.questions.count - 1 ? "結果を見る" : "次へ") {
                    onNext(question: question)
                }
                .buttonStyle(.borderedProminent)
                .tint(PopTheme.accent)
                .disabled(selected[question.id] == nil || isSubmitting)
            }

            if selected[question.id] == nil {
                Text("次へ進むには回答を1つ選択してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .popCard(cornerRadius: 16, padding: 12)
    }

    private func selectedScaleText(_ question: Question) -> String? {
        guard shouldUseScaleStyle(question: question) else {
            return selectedText(question)
        }

        let sortedChoices = question.choices.sorted(by: { $0.order < $1.order })
        guard let choiceID = selected[question.id],
              let selectedIndex = sortedChoices.firstIndex(where: { $0.id == choiceID }) else {
            return nil
        }

        return scaleSelectionSummary(index: selectedIndex)
    }

    private func scaleSelectionSummary(index: Int) -> String {
        switch index {
        case 0: return "とてもそう思う"
        case 1: return "ややそう思う"
        case 2: return "少しそう思う"
        case 3: return "どちらでもない"
        case 4: return "少しそう思わない"
        case 5: return "ややそう思わない"
        case 6: return "とてもそう思わない"
        default: return "選択済み"
        }
    }

    private func selectedText(_ question: Question) -> String? {
        guard let choiceID = selected[question.id],
              let choice = question.choices.first(where: { $0.id == choiceID }) else {
            return nil
        }
        return choice.text
    }

    private func bubbleSize(index: Int, total: Int) -> CGFloat {
        switch total {
        case 2:
            return 44
        case 3:
            return [38, 30, 38][index]
        case 4:
            return [38, 30, 30, 38][index]
        case 5:
            return [40, 34, 26, 34, 40][index]
        case 6:
            return [40, 34, 28, 28, 34, 40][index]
        default:
            return [42, 36, 30, 24, 30, 36, 42][index]
        }
    }

    private func bubbleColor(index: Int, total: Int) -> Color {
        if total <= 1 { return PopTheme.accent }
        let ratio = Double(index) / Double(total - 1)
        let left = UIColor(PopTheme.accent)
        let right = UIColor(PopTheme.accentAlt)

        var lr: CGFloat = 0
        var lg: CGFloat = 0
        var lb: CGFloat = 0
        var la: CGFloat = 0

        var rr: CGFloat = 0
        var rg: CGFloat = 0
        var rb: CGFloat = 0
        var ra: CGFloat = 0

        left.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        right.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)

        return Color(
            red: lr + CGFloat(ratio) * (rr - lr),
            green: lg + CGFloat(ratio) * (rg - lg),
            blue: lb + CGFloat(ratio) * (rb - lb)
        )
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
                if state.activeShareToken != nil || (quiz.visibility == .directoryPublic && quiz.creatorID != nil) {
                    let payload = SubmitResponseRequest(
                        quizPublicID: quiz.publicID,
                        token: state.activeShareToken,
                        answers: answers
                    )
                    let submitted = try await state.apiClient.submitResponse(payload: payload)
                    let profile = ResultCodeEngine.profile(for: submitted.resultCode, in: quiz.resultProfiles)
                        ?? QuizResultProfile.default(for: submitted.resultCode)

                    state.latestResult = DiagnosisResult(
                        id: submitted.resultID,
                        quizID: quiz.id,
                        resultCode: submitted.resultCode,
                        roleName: submitted.roleName.isEmpty ? profile.roleName : submitted.roleName,
                        summary: submitted.summary.isEmpty ? profile.summary : submitted.summary,
                        detail: submitted.detail.isEmpty ? profile.detail : submitted.detail,
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
