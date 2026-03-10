import SwiftUI

struct QuizEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: AppState
    @StateObject private var imageStore = CharacterImageStore.shared

    let editingQuiz: Quiz?
    @State private var title: String
    @State private var description: String
    @State private var visibility: Visibility
    @State private var questions: [QuestionDraft]
    @State private var axisDefinitions: [AxisDefinition]
    @State private var resultProfiles: [QuizResultProfile]
    @State private var showingCharacterImages = false
    @State private var draftPublicID: String
    @State private var pendingDeleteQuestionID: UUID?

    var onSave: (Quiz) -> Void

    init(editingQuiz: Quiz? = nil, onSave: @escaping (Quiz) -> Void) {
        self.editingQuiz = editingQuiz
        self.onSave = onSave

        let initialAxisDefinitions = AxisDefinition.normalized(editingQuiz?.axisDefinitions ?? AxisDefinition.defaultSet())
        _title = State(initialValue: editingQuiz?.title ?? "")
        _description = State(initialValue: editingQuiz?.description ?? "")
        _visibility = State(initialValue: editingQuiz?.visibility ?? .linkOnly)
        _questions = State(initialValue: Self.initialDrafts(from: editingQuiz))
        _axisDefinitions = State(initialValue: initialAxisDefinitions)
        _resultProfiles = State(
            initialValue: QuizResultProfile.normalized(editingQuiz?.resultProfiles ?? [], axisDefinitions: initialAxisDefinitions)
        )
        _draftPublicID = State(initialValue: editingQuiz?.publicID ?? UUID().uuidString.lowercased())
    }

    private let scaleValues = [3, 2, 1, 0, -1, -2, -3]

    private var normalizedAxisDefinitions: [AxisDefinition] {
        AxisDefinition.normalized(axisDefinitions)
    }

    private var activeAxisDefinitions: [AxisDefinition] {
        normalizedAxisDefinitions.filter(\.isEnabled)
    }

    private var activeAxisIDs: [AxisID] {
        activeAxisDefinitions.map(\.axisID)
    }

    private var activeResultProfiles: [QuizResultProfile] {
        QuizResultProfile
            .normalized(resultProfiles, axisDefinitions: normalizedAxisDefinitions)
            .sorted(by: { $0.resultCode < $1.resultCode })
    }

    private var resultPatternCount: Int {
        activeResultProfiles.count
    }

    private var canSave: Bool {
        let titleValue = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titleValue.isEmpty else { return false }
        guard !activeAxisIDs.isEmpty else { return false }
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
            if !activeAxisIDs.contains(question.axis) {
                return false
            }
        }

        for axis in normalizedAxisDefinitions {
            if axis.positiveCode.isEmpty || axis.negativeCode.isEmpty { return false }
            if axis.positiveCode == axis.negativeCode { return false }
        }

        for profile in activeResultProfiles {
            if profile.roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
            if profile.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }

        return true
    }

    private var configuredImageCount: Int {
        activeResultProfiles.filter { imageStore.hasCustomImage(for: $0.resultCode, quizPublicID: draftPublicID) }.count
    }

    private var questionIDs: [UUID] {
        questions.map(\.id)
    }

    var body: some View {
        ZStack {
            PopBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerSection
                    axisSettingsSection
                    questionsSection
                    resultProfileSection
                    resultImageSection
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
                    quizTitle: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新規診断" : title,
                    profiles: activeResultProfiles
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
        .onAppear {
            normalizeQuestionsForEnabledAxes()
            syncResultProfiles()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editingQuiz == nil ? "新しい診断を作る" : "診断内容を編集")
                .font(.title2.bold())
                .foregroundStyle(PopTheme.textPrimary)

            Text("最初に使う英文字を決めて、次に設問、最後に診断結果を整えます。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("タイトル（必須）", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("説明（任意）", text: $description, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            Picker("公開範囲", selection: $visibility) {
                ForEach(Visibility.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text(visibility.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var axisSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("使う英文字")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            HStack(spacing: 12) {
                Label("\(activeAxisDefinitions.count)軸を使用", systemImage: "slider.horizontal.3")
                Label("\(resultPatternCount)タイプ", systemImage: "person.3.sequence.fill")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(PopTheme.accentAlt)

            Text("使う軸だけONにすると、用意する結果タイプ数を減らせます。各軸で左右の英字コードと同点時ルールを決めてください。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(normalizedAxisDefinitions, id: \.axisID) { axis in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Text(axis.isEnabled ? "使用中" : "未使用")
                            .font(.caption.bold())
                            .foregroundStyle(axis.isEnabled ? PopTheme.accentAlt : .secondary)
                    }

                    Toggle("この軸を診断に使う", isOn: enabledBinding(axis.axisID))
                        .disabled(axis.isEnabled && activeAxisDefinitions.count == 1)

                    HStack(spacing: 8) {
                        TextField("左コード", text: positiveCodeBinding(axis.axisID))
                            .textFieldStyle(.roundedBorder)

                        TextField("右コード", text: negativeCodeBinding(axis.axisID))
                            .textFieldStyle(.roundedBorder)
                    }

                    Picker("同点時", selection: tieBreakBinding(axis.axisID)) {
                        Text("同点時は左を使う").tag(TieBreakSide.positive)
                        Text("同点時は右を使う").tag(TieBreakSide.negative)
                    }
                    .pickerStyle(.segmented)

                    Text("結果コード例: \(axis.positiveCode) / \(axis.negativeCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .popCard(cornerRadius: 18)
    }

    private var resultProfileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("診断結果（\(resultPatternCount)パターン）")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            Text("有効な英字の組み合わせごとに、役割名・要約・詳細を設定できます。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(activeResultProfiles, id: \.resultCode) { profile in
                resultProfileCard(profile)
            }
        }
        .popCard(cornerRadius: 18)
    }

    @ViewBuilder
    private func resultProfileCard(_ profile: QuizResultProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(profile.resultCode)
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            TextField("役割名", text: roleNameBinding(profile.resultCode))
                .textFieldStyle(.roundedBorder)

            TextField("要約", text: summaryBinding(profile.resultCode), axis: .vertical)
                .lineLimit(2...3)
                .textFieldStyle(.roundedBorder)

            TextField("詳細説明", text: detailBinding(profile.resultCode), axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var resultImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("結果画像（診断ごと）")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            Text("結果コードごとにこの診断専用の画像を設定できます。未設定時はデフォルト画像が表示されます。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                showingCharacterImages = true
            } label: {
                Label("タイプ画像を設定 \(configuredImageCount)/\(activeResultProfiles.count)", systemImage: "person.crop.square")
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

            Label("\(questions.count)問 / 最低\(QuizValidator.minQuestions)問", systemImage: "list.number")
                .font(.subheadline)

            Text("回答UIは『左ラベル ○○○○○○○ 右ラベル』の7段階で固定です。設問ごとに、どの英字軸へ効かせるかを選べます。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(questionIDs, id: \.self) { questionID in
                questionCard(questionID: questionID)
            }

            Button {
                guard questions.count < QuizValidator.maxQuestions else { return }
                questions.append(makeQuestionDraft(index: questions.count))
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
        let axisID = questionAxis(questionID)
        let axisDefinition = axisDefinition(for: axisID)

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
                ForEach(activeAxisDefinitions, id: \.axisID) { item in
                    Text("\(item.positiveCode) / \(item.negativeCode)").tag(item.axisID)
                }
            }
            .pickerStyle(.segmented)

            Toggle(
                isOn: agreeMapsToPositiveBinding(questionID)
            ) {
                Text("左ラベルを \(axisDefinition.positiveCode) 側として採点")
                    .font(.subheadline)
            }

            Text("現在: 左=\(questionAgreeMapsToPositive(questionID) ? axisDefinition.positiveCode : axisDefinition.negativeCode) / 右=\(questionAgreeMapsToPositive(questionID) ? axisDefinition.negativeCode : axisDefinition.positiveCode)")
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

    private func axisIndex(_ axisID: AxisID) -> Int? {
        axisDefinitions.firstIndex(where: { $0.axisID == axisID })
    }

    private func fallbackAxisID(for index: Int = 0) -> AxisID {
        let pool = activeAxisIDs.isEmpty ? AxisID.allCases : activeAxisIDs
        return pool[index % pool.count]
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

    private func questionAxisBinding(_ questionID: UUID) -> Binding<AxisID> {
        Binding(
            get: {
                guard let qIndex = questionIndex(questionID) else { return fallbackAxisID() }
                let axis = questions[qIndex].axis
                return activeAxisIDs.contains(axis) ? axis : fallbackAxisID()
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

    private func enabledBinding(_ axisID: AxisID) -> Binding<Bool> {
        Binding(
            get: {
                guard let index = axisIndex(axisID) else { return true }
                return axisDefinitions[index].isEnabled
            },
            set: { newValue in
                updateAxisEnabled(axisID, isEnabled: newValue)
            }
        )
    }

    private func positiveCodeBinding(_ axisID: AxisID) -> Binding<String> {
        Binding(
            get: {
                guard let index = axisIndex(axisID) else { return axisID.defaultPositiveCode }
                return axisDefinitions[index].positiveCode
            },
            set: { newValue in
                guard let index = axisIndex(axisID) else { return }
                axisDefinitions[index].positiveCode = AxisDefinition.sanitizeCode(newValue, fallback: axisID.defaultPositiveCode)
                syncResultProfiles()
            }
        )
    }

    private func negativeCodeBinding(_ axisID: AxisID) -> Binding<String> {
        Binding(
            get: {
                guard let index = axisIndex(axisID) else { return axisID.defaultNegativeCode }
                return axisDefinitions[index].negativeCode
            },
            set: { newValue in
                guard let index = axisIndex(axisID) else { return }
                axisDefinitions[index].negativeCode = AxisDefinition.sanitizeCode(newValue, fallback: axisID.defaultNegativeCode)
                syncResultProfiles()
            }
        )
    }

    private func tieBreakBinding(_ axisID: AxisID) -> Binding<TieBreakSide> {
        Binding(
            get: {
                guard let index = axisIndex(axisID) else { return .positive }
                return axisDefinitions[index].tieBreak
            },
            set: { newValue in
                guard let index = axisIndex(axisID) else { return }
                axisDefinitions[index].tieBreak = newValue
                syncResultProfiles()
            }
        )
    }

    private func roleNameBinding(_ resultCode: String) -> Binding<String> {
        Binding(
            get: { profile(for: resultCode).roleName },
            set: { newValue in
                updateProfile(resultCode: resultCode) { $0.roleName = newValue }
            }
        )
    }

    private func summaryBinding(_ resultCode: String) -> Binding<String> {
        Binding(
            get: { profile(for: resultCode).summary },
            set: { newValue in
                updateProfile(resultCode: resultCode) { $0.summary = newValue }
            }
        )
    }

    private func detailBinding(_ resultCode: String) -> Binding<String> {
        Binding(
            get: { profile(for: resultCode).detail },
            set: { newValue in
                updateProfile(resultCode: resultCode) { $0.detail = newValue }
            }
        )
    }

    private func profile(for resultCode: String) -> QuizResultProfile {
        if let existing = resultProfiles.first(where: { $0.resultCode == resultCode }) {
            return existing
        }
        return QuizResultProfile.default(for: resultCode)
    }

    private func updateProfile(resultCode: String, update: (inout QuizResultProfile) -> Void) {
        if let index = resultProfiles.firstIndex(where: { $0.resultCode == resultCode }) {
            update(&resultProfiles[index])
            return
        }

        var created = QuizResultProfile.default(for: resultCode)
        update(&created)
        resultProfiles.append(created)
    }

    private func syncResultProfiles() {
        resultProfiles = QuizResultProfile.normalized(resultProfiles, axisDefinitions: normalizedAxisDefinitions)
    }

    private func questionAxis(_ questionID: UUID) -> AxisID {
        guard let qIndex = questionIndex(questionID) else { return fallbackAxisID() }
        let axis = questions[qIndex].axis
        return activeAxisIDs.contains(axis) ? axis : fallbackAxisID()
    }

    private func axisDefinition(for axisID: AxisID) -> AxisDefinition {
        normalizedAxisDefinitions.first(where: { $0.axisID == axisID }) ?? .default(for: fallbackAxisID())
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

    private func updateAxisEnabled(_ axisID: AxisID, isEnabled: Bool) {
        guard let index = axisIndex(axisID) else { return }
        let currentlyEnabled = axisDefinitions[index].isEnabled

        if currentlyEnabled == isEnabled {
            return
        }

        if !isEnabled && activeAxisDefinitions.count <= 1 {
            return
        }

        axisDefinitions[index].isEnabled = isEnabled
        normalizeQuestionsForEnabledAxes()
        syncResultProfiles()
    }

    private func normalizeQuestionsForEnabledAxes() {
        let validAxes = Set(activeAxisIDs)
        let fallback = fallbackAxisID()

        for index in questions.indices where !validAxes.contains(questions[index].axis) {
            questions[index].axis = fallback
        }
    }

    private func makeQuestionDraft(index: Int) -> QuestionDraft {
        QuestionDraft.sample(index: index, axisPool: activeAxisIDs)
    }

    private func saveQuiz() {
        normalizeQuestionsForEnabledAxes()

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

        let normalizedAxisDefinitions = self.normalizedAxisDefinitions
        let normalizedResultProfiles = QuizResultProfile.normalized(resultProfiles, axisDefinitions: normalizedAxisDefinitions)

        let quiz = Quiz(
            id: editingQuiz?.id ?? UUID(),
            publicID: draftPublicID,
            creatorID: editingQuiz?.creatorID,
            title: title,
            description: description,
            visibility: visibility,
            questions: mappedQuestions,
            axisDefinitions: normalizedAxisDefinitions,
            resultProfiles: normalizedResultProfiles,
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

struct QuestionDraft: Identifiable {
    let id = UUID()
    var prompt: String
    var agreeText: String
    var disagreeText: String
    var axis: AxisID
    var agreeMapsToPositive: Bool

    static func sample(index: Int, axisPool: [AxisID] = AxisID.allCases) -> QuestionDraft {
        let pool = axisPool.isEmpty ? AxisID.allCases : axisPool
        let defaultAxis = pool[index % pool.count]
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
        let inferredAxis = inferAxis(from: sortedChoices) ?? AxisID.allCases[fallbackIndex % AxisID.allCases.count]

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

    private static func inferAxis(from choices: [Choice]) -> AxisID? {
        guard !choices.isEmpty else { return nil }

        let scores: [(AxisID, Int)] = [
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
