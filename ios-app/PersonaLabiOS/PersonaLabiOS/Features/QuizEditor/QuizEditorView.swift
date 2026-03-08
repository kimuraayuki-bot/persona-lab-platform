import SwiftUI

struct QuizEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: AppState
    @StateObject private var imageStore = CharacterImageStore.shared

    let editingQuiz: Quiz?
    @State private var title: String
    @State private var description: String
    @State private var questions: [QuestionDraft]
    @State private var showingCharacterImages = false
    @State private var draftPublicID: String
    @State private var pendingDeleteQuestionID: UUID?

    var onSave: (Quiz) -> Void

    init(editingQuiz: Quiz? = nil, onSave: @escaping (Quiz) -> Void) {
        self.editingQuiz = editingQuiz
        self.onSave = onSave
        _title = State(initialValue: editingQuiz?.title ?? "")
        _description = State(initialValue: editingQuiz?.description ?? "")
        _questions = State(initialValue: Self.initialDrafts(from: editingQuiz))
        _draftPublicID = State(initialValue: editingQuiz?.publicID ?? UUID().uuidString.lowercased())
    }

    private let scaleValues = [3, 2, 1, 0, -1, -2, -3]

    private var canSave: Bool {
        let titleValue = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titleValue.isEmpty else { return false }
        guard questions.count >= QuizValidator.minQuestions else { return false }

        for question in questions {
            if question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
            if question.agreeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
            if question.disagreeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }

        return true
    }

    private var guidanceText: String {
        if canSave {
            return "入力OK。保存して共有リンク作成へ進めます。"
        }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "タイトルを入力してください。"
        }

        if questions.count < QuizValidator.minQuestions {
            return "設問は最低\(QuizValidator.minQuestions)問必要です。"
        }

        return "未入力の項目があります。"
    }

    private var configuredImageCount: Int {
        MBTIType.allCases.filter { imageStore.hasCustomImage(for: $0, quizPublicID: draftPublicID) }.count
    }

    private var questionIDs: [UUID] {
        questions.map(\.id)
    }

    var body: some View {
        ZStack {
            PopBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    basicInfoSection
                    guidanceSection
                    resultImageSection
                    questionsSection
                }
                .padding(16)
            }
        }
        .navigationTitle(editingQuiz == nil ? "診断作成" : "診断編集")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { saveQuiz() }
                    .disabled(!canSave)
            }
        }
        .sheet(isPresented: $showingCharacterImages) {
            NavigationStack {
                CharacterImageSettingsView(
                    quizPublicID: draftPublicID,
                    quizTitle: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新規診断" : title
                )
            }
        }
        .confirmationDialog(
            "この設問を削除しますか？",
            isPresented: Binding(
                get: { pendingDeleteQuestionID != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteQuestionID = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let id = pendingDeleteQuestionID {
                    removeQuestion(id)
                }
                pendingDeleteQuestionID = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingDeleteQuestionID = nil
            }
        } message: {
            Text("この設問が削除されます。")
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("基本情報")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            TextField("タイトル（必須）", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("説明（任意）", text: $description, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
        .popCard(cornerRadius: 18)
    }

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("入力ガイド")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            Label("\(questions.count)問 / 最低\(QuizValidator.minQuestions)問", systemImage: "list.number")
                .font(.subheadline)

            Text("回答UIは『左ラベル ○○○○○○○ 右ラベル』の7段階で固定です。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(guidanceText)
                .font(.footnote)
                .foregroundStyle(canSave ? .green : .orange)
        }
        .popCard(cornerRadius: 18)
    }

    private var resultImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("結果画像（診断ごと）")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            Text("16タイプ別にこの診断専用の画像を設定できます。未設定時はデフォルト画像が表示されます。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                showingCharacterImages = true
            } label: {
                Label("タイプ画像を設定 \(configuredImageCount)/\(MBTIType.allCases.count)", systemImage: "person.crop.square")
            }
            .buttonStyle(.bordered)
        }
        .popCard(cornerRadius: 18)
    }

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("設問")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            ForEach(questionIDs, id: \.self) { questionID in
                questionCard(questionID: questionID)
            }

            Button {
                guard questions.count < QuizValidator.maxQuestions else { return }
                questions.append(.sample(index: questions.count))
            } label: {
                Label("設問を追加", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PopTheme.accent)
            .disabled(questions.count >= QuizValidator.maxQuestions)
        }
        .popCard(cornerRadius: 18)
    }

    @ViewBuilder
    private func questionCard(questionID: UUID) -> some View {
        let number = (questionIndex(questionID) ?? 0) + 1
        let axis = questionAxis(questionID)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Q\(number)")
                    .font(.headline)
                    .foregroundStyle(PopTheme.textPrimary)

                Spacer()

                Button(role: .destructive) {
                    pendingDeleteQuestionID = questionID
                } label: {
                    Label("設問削除", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(questions.count <= 1)
            }

            TextField("質問文", text: questionPromptBinding(questionID))
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                TextField("左ラベル", text: agreeTextBinding(questionID))
                    .textFieldStyle(.roundedBorder)

                TextField("右ラベル", text: disagreeTextBinding(questionID))
                    .textFieldStyle(.roundedBorder)
            }

            Picker("判定軸", selection: questionAxisBinding(questionID)) {
                ForEach(QuestionAxis.allCases) { item in
                    Text(item.pairLabel).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Toggle(
                isOn: agreeMapsToPositiveBinding(questionID)
            ) {
                Text("左ラベルを \(axis.positiveTitle) 側として採点")
                    .font(.subheadline)
            }

            Text("現在: 左=\(questionAgreeMapsToPositive(questionID) ? axis.positiveTitle : axis.negativeTitle) / 右=\(questionAgreeMapsToPositive(questionID) ? axis.negativeTitle : axis.positiveTitle)")
                .font(.caption)
                .foregroundStyle(.secondary)

            scalePreview(questionID: questionID)

            Text("中央が中立、外側ほど強い回答になります。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func scalePreview(questionID: UUID) -> some View {
        let agree = questionAgreeText(questionID)
        let disagree = questionDisagreeText(questionID)

        VStack(spacing: 8) {
            HStack {
                Text(agree)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(disagree)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(PopTheme.accent.opacity(index == 3 ? 0.3 : 0.55))
                        .frame(width: previewBubbleSize(index), height: previewBubbleSize(index))
                        .overlay {
                            Circle().stroke(.white.opacity(0.7), lineWidth: 1)
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func previewBubbleSize(_ index: Int) -> CGFloat {
        [42, 36, 30, 24, 30, 36, 42][index]
    }

    private func questionIndex(_ questionID: UUID) -> Int? {
        questions.firstIndex(where: { $0.id == questionID })
    }

    private func questionPromptBinding(_ questionID: UUID) -> Binding<String> {
        Binding(
            get: {
                guard let qIndex = questionIndex(questionID) else { return "" }
                return questions[qIndex].prompt
            },
            set: { newValue in
                guard let qIndex = questionIndex(questionID) else { return }
                questions[qIndex].prompt = newValue
            }
        )
    }

    private func agreeTextBinding(_ questionID: UUID) -> Binding<String> {
        Binding(
            get: {
                guard let qIndex = questionIndex(questionID) else { return "" }
                return questions[qIndex].agreeText
            },
            set: { newValue in
                guard let qIndex = questionIndex(questionID) else { return }
                questions[qIndex].agreeText = newValue
            }
        )
    }

    private func disagreeTextBinding(_ questionID: UUID) -> Binding<String> {
        Binding(
            get: {
                guard let qIndex = questionIndex(questionID) else { return "" }
                return questions[qIndex].disagreeText
            },
            set: { newValue in
                guard let qIndex = questionIndex(questionID) else { return }
                questions[qIndex].disagreeText = newValue
            }
        )
    }

    private func questionAxisBinding(_ questionID: UUID) -> Binding<QuestionAxis> {
        Binding(
            get: {
                guard let qIndex = questionIndex(questionID) else { return .ei }
                return questions[qIndex].axis
            },
            set: { newValue in
                guard let qIndex = questionIndex(questionID) else { return }
                questions[qIndex].axis = newValue
            }
        )
    }

    private func agreeMapsToPositiveBinding(_ questionID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                guard let qIndex = questionIndex(questionID) else { return true }
                return questions[qIndex].agreeMapsToPositive
            },
            set: { newValue in
                guard let qIndex = questionIndex(questionID) else { return }
                questions[qIndex].agreeMapsToPositive = newValue
            }
        )
    }

    private func questionAxis(_ questionID: UUID) -> QuestionAxis {
        guard let qIndex = questionIndex(questionID) else { return .ei }
        return questions[qIndex].axis
    }

    private func questionAgreeMapsToPositive(_ questionID: UUID) -> Bool {
        guard let qIndex = questionIndex(questionID) else { return true }
        return questions[qIndex].agreeMapsToPositive
    }

    private func questionAgreeText(_ questionID: UUID) -> String {
        guard let qIndex = questionIndex(questionID) else { return "そう思う" }
        return questions[qIndex].agreeText
    }

    private func questionDisagreeText(_ questionID: UUID) -> String {
        guard let qIndex = questionIndex(questionID) else { return "そう思わない" }
        return questions[qIndex].disagreeText
    }

    private func saveQuiz() {
        let mappedQuestions = questions.enumerated().map { index, q in
            let choices = scaleValues.enumerated().map { choiceIndex, value in
                let signedValue = q.agreeMapsToPositive ? value : -value
                return Choice(
                    text: scaleChoiceText(index: choiceIndex, agreeText: q.agreeText, disagreeText: q.disagreeText),
                    order: choiceIndex,
                    axisDelta: q.axis.axisScore(from: signedValue)
                )
            }

            return Question(
                prompt: q.prompt,
                order: index,
                choices: choices
            )
        }

        let quiz = Quiz(
            id: editingQuiz?.id ?? UUID(),
            publicID: draftPublicID,
            creatorID: editingQuiz?.creatorID,
            title: title,
            description: description,
            visibility: editingQuiz?.visibility ?? .linkOnly,
            questions: mappedQuestions,
            createdAt: editingQuiz?.createdAt ?? Date()
        )

        do {
            try QuizValidator.validate(quiz: quiz)
            onSave(quiz)
            dismiss()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func scaleChoiceText(index: Int, agreeText: String, disagreeText: String) -> String {
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

    private func removeQuestion(_ questionID: UUID) {
        guard questions.count > 1 else { return }
        guard let index = questionIndex(questionID) else { return }
        questions.remove(at: index)
    }

    private static func initialDrafts(from quiz: Quiz?) -> [QuestionDraft] {
        guard let quiz else {
            return [QuestionDraft.sample(index: 0)]
        }

        let sorted = quiz.questions.sorted(by: { $0.order < $1.order })
        guard !sorted.isEmpty else {
            return [QuestionDraft.sample(index: 0)]
        }

        return sorted.enumerated().map { index, question in
            QuestionDraft.from(question: question, fallbackIndex: index)
        }
    }
}

enum QuestionAxis: String, CaseIterable, Identifiable {
    case ei
    case sn
    case tf
    case jp

    var id: String { rawValue }

    var pairLabel: String {
        switch self {
        case .ei: return "E / I"
        case .sn: return "S / N"
        case .tf: return "T / F"
        case .jp: return "J / P"
        }
    }

    var positiveTitle: String {
        switch self {
        case .ei: return "E"
        case .sn: return "S"
        case .tf: return "T"
        case .jp: return "J"
        }
    }

    var negativeTitle: String {
        switch self {
        case .ei: return "I"
        case .sn: return "N"
        case .tf: return "F"
        case .jp: return "P"
        }
    }

    func axisScore(from signedValue: Int) -> AxisScore {
        switch self {
        case .ei: return AxisScore(ei: signedValue)
        case .sn: return AxisScore(sn: signedValue)
        case .tf: return AxisScore(tf: signedValue)
        case .jp: return AxisScore(jp: signedValue)
        }
    }

    func value(from axisScore: AxisScore) -> Int {
        switch self {
        case .ei: return axisScore.ei
        case .sn: return axisScore.sn
        case .tf: return axisScore.tf
        case .jp: return axisScore.jp
        }
    }
}

struct QuestionDraft: Identifiable {
    let id = UUID()
    var prompt: String
    var agreeText: String
    var disagreeText: String
    var axis: QuestionAxis
    var agreeMapsToPositive: Bool

    static func sample(index: Int) -> QuestionDraft {
        let defaultAxis = QuestionAxis.allCases[index % QuestionAxis.allCases.count]
        return QuestionDraft(
            prompt: "質問\(index + 1)",
            agreeText: "そう思う",
            disagreeText: "そう思わない",
            axis: defaultAxis,
            agreeMapsToPositive: true
        )
    }

    static func from(question: Question, fallbackIndex: Int) -> QuestionDraft {
        let sortedChoices = question.choices.sorted(by: { $0.order < $1.order })
        let inferredAxis = inferAxis(from: sortedChoices) ?? QuestionAxis.allCases[fallbackIndex % QuestionAxis.allCases.count]

        let firstChoice = sortedChoices.first
        let lastChoice = sortedChoices.last

        let leftLabel = normalizeEdgeLabel(firstChoice?.text, fallback: "そう思う")
        let rightLabel = normalizeEdgeLabel(lastChoice?.text, fallback: "そう思わない")

        let agreeMapsToPositive: Bool = {
            guard let firstChoice, let lastChoice else { return true }
            let first = inferredAxis.value(from: firstChoice.axisDelta)
            let last = inferredAxis.value(from: lastChoice.axisDelta)
            if first == last { return true }
            return first > last
        }()

        return QuestionDraft(
            prompt: question.prompt,
            agreeText: leftLabel,
            disagreeText: rightLabel,
            axis: inferredAxis,
            agreeMapsToPositive: agreeMapsToPositive
        )
    }

    private static func inferAxis(from choices: [Choice]) -> QuestionAxis? {
        guard !choices.isEmpty else { return nil }

        let scores: [(QuestionAxis, Int)] = [
            (.ei, choices.reduce(0) { $0 + abs($1.axisDelta.ei) }),
            (.sn, choices.reduce(0) { $0 + abs($1.axisDelta.sn) }),
            (.tf, choices.reduce(0) { $0 + abs($1.axisDelta.tf) }),
            (.jp, choices.reduce(0) { $0 + abs($1.axisDelta.jp) })
        ]

        return scores.max(by: { $0.1 < $1.1 })?.0
    }

    private static func normalizeEdgeLabel(_ text: String?, fallback: String) -> String {
        guard let text else { return fallback }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        if trimmed == "どちらでもない" {
            return fallback
        }

        let prefixes = ["とても", "やや", "少し"]
        for prefix in prefixes where trimmed.hasPrefix(prefix) && trimmed.count > prefix.count {
            return String(trimmed.dropFirst(prefix.count))
        }

        return trimmed
    }
}
