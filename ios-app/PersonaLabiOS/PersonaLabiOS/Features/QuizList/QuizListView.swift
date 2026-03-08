import SwiftUI

struct QuizListView: View {
    @EnvironmentObject private var state: AppState

    @State private var showingEditor = false
    @State private var showingCharacterImages = false
    @State private var editingQuiz: Quiz?

    @State private var showingShareSheet = false
    @State private var isPreparingShare = false
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationStack {
            ZStack {
                PopBackdrop().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header

                        if state.quizzes.isEmpty {
                            emptyState
                        } else {
                            ForEach(state.quizzes) { quiz in
                                quizCard(quiz)
                                    .accessibilityIdentifier("quiz_\(quiz.publicID)")
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("診断一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingCharacterImages = true
                        } label: {
                            Label("共通キャラ画像設定", systemImage: "person.crop.square.filled.and.at.rectangle")
                        }

                        Button(role: .destructive) {
                            state.logout()
                        } label: {
                            Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle")
                    }
                    .accessibilityLabel("メニュー")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingQuiz = nil
                        showingEditor = true
                    } label: {
                        Label("新規診断", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("新規診断")
                }
            }
            .sheet(
                isPresented: $showingEditor,
                onDismiss: { editingQuiz = nil }
            ) {
                NavigationStack {
                    QuizEditorView(editingQuiz: editingQuiz) { savedQuiz in
                        state.upsertQuiz(savedQuiz)
                    }
                }
            }
            .sheet(isPresented: $showingCharacterImages) {
                NavigationStack {
                    CharacterImageSettingsView()
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
            .navigationDestination(isPresented: Binding(
                get: { state.activeQuiz != nil },
                set: { if !$0 { state.activeQuiz = nil } }
            )) {
                if let quiz = state.activeQuiz {
                    QuizTakingView(quiz: quiz)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.currentUserEmail ?? "ゲスト")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("診断を作ってリンク共有")
                .font(.title3.bold())
                .foregroundStyle(PopTheme.textPrimary)

            Text("各診断カードから編集・リンク発行ができます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .popCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("まだ診断がありません", systemImage: "square.and.pencil")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            Text("まずは4問以上の質問を作成すると、リンク共有まで進められます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                editingQuiz = nil
                showingEditor = true
            } label: {
                Label("最初の診断を作成", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(PopTheme.accent)
        }
        .popCard(cornerRadius: 18)
    }

    private func quizCard(_ quiz: Quiz) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(quiz.title)
                    .font(.headline)
                    .foregroundStyle(PopTheme.textPrimary)
                Spacer()
            }

            Text(quiz.description.isEmpty ? "説明未設定" : quiz.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Label("設問 \(quiz.questions.count)", systemImage: "list.bullet.rectangle")
                Spacer()
                Label("回答リンク対応", systemImage: "link")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    state.activeQuiz = quiz
                } label: {
                    Label("回答", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)

                Button {
                    editingQuiz = quiz
                    showingEditor = true
                } label: {
                    Label("編集", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await prepareShare(for: quiz) }
                } label: {
                    Label(isPreparingShare ? "発行中" : "リンク発行", systemImage: "link.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(PopTheme.accent)
                .disabled(isPreparingShare)
            }
        }
        .popCard(cornerRadius: 18)
    }

    private func prepareShare(for quiz: Quiz) async {
        isPreparingShare = true
        defer { isPreparingShare = false }

        await state.buildShareMessage(for: quiz)
        guard let payload = state.sharePayload else {
            return
        }

        shareItems = ["\(payload.message)\n\(payload.shareURL.absoluteString)"]
        showingShareSheet = true
    }
}
