import SwiftUI

struct PublicQuizRankingView: View {
    @EnvironmentObject private var state: AppState

    @State private var ranking: [PublicQuizRankingEntry] = []
    @State private var isLoading = false
    @State private var loadingQuizPublicID: String?
    @State private var reportTarget: PublicQuizRankingEntry?
    @State private var helperMessage: String?

    var body: some View {
        ZStack {
            PopBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    introCard

                    if isLoading && ranking.isEmpty {
                        ProgressView("ランキングを読み込み中...")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if ranking.isEmpty {
                        emptyState
                    } else {
                        ForEach(ranking) { entry in
                            rankingCard(entry)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("みんなのランキング")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadRanking() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            guard ranking.isEmpty else { return }
            await loadRanking()
        }
        .refreshable {
            await loadRanking()
        }
        .sheet(item: $reportTarget) { entry in
            ReportQuizSheet(
                quizPublicID: entry.quiz.publicID,
                quizTitle: entry.quiz.title,
                source: .iosRanking,
                pageURL: "myapp://ranking"
            ) {
                helperMessage = "通報を送信しました。確認後に必要があれば掲載停止します。"
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("公開ランキング", systemImage: "chart.bar.fill")
                .font(.caption.bold())
                .foregroundStyle(PopTheme.accentAlt)

            Text("回答数ランキング")
                .font(.title3.bold())
                .foregroundStyle(PopTheme.textPrimary)

            Text("ランキング掲載を許可した診断だけを表示しています。気になる診断はそのまま回答できます。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let helperMessage {
                Text(helperMessage)
                    .font(.footnote)
                    .foregroundStyle(PopTheme.accentAlt)
            }
        }
        .popCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("まだ公開ランキングがありません", systemImage: "sparkles.rectangle.stack")
                .font(.headline)
                .foregroundStyle(PopTheme.textPrimary)

            Text("公開診断への回答が蓄積されると、ここにランキングが表示されます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .popCard(cornerRadius: 18)
    }

    private func rankingCard(_ entry: PublicQuizRankingEntry) -> some View {
        let isOpening = loadingQuizPublicID == entry.quiz.publicID

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("#\(entry.rank)")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(PopTheme.accent))

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.quiz.title)
                        .font(.headline)
                        .foregroundStyle(PopTheme.textPrimary)

                    if !entry.quiz.description.isEmpty {
                        Text(entry.quiz.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack {
                Label("回答 \(entry.totalResponses) 件", systemImage: "person.2.fill")
                Spacer()
                Label(formattedUpdatedAt(entry.updatedAt), systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if entry.topResults.isEmpty {
                Text("まだタイプ別の集計はありません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(entry.topResults) { result in
                        HStack(spacing: 10) {
                            Text(result.resultCode)
                                .font(.caption.bold())
                                .foregroundStyle(PopTheme.textPrimary)
                                .frame(width: 54, alignment: .leading)

                            GeometryReader { proxy in
                                let ratio = entry.totalResponses > 0
                                    ? CGFloat(result.responseCount) / CGFloat(entry.totalResponses)
                                    : 0

                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                                        .fill(Color.white.opacity(0.7))
                                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: [PopTheme.accent, PopTheme.accentAlt],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: max(proxy.size.width * max(ratio, 0.06), 12))
                                }
                            }
                            .frame(height: 8)

                            Text("\(result.responseCount)件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await openQuiz(entry) }
                } label: {
                    Label(isOpening ? "読み込み中..." : "この診断を遊ぶ", systemImage: isOpening ? "hourglass" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PopTheme.accent)
                .disabled(isOpening)

                Button {
                    reportTarget = entry
                } label: {
                    Label("通報", systemImage: "flag")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .popCard(cornerRadius: 18)
    }

    private func formattedUpdatedAt(_ value: Date?) -> String {
        guard let value else {
            return "更新日時不明"
        }

        return value.formatted(date: .abbreviated, time: .shortened)
    }

    private func loadRanking() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            ranking = try await state.apiClient.fetchQuizRanking(limit: 20)
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func openQuiz(_ entry: PublicQuizRankingEntry) async {
        guard loadingQuizPublicID == nil else { return }
        loadingQuizPublicID = entry.quiz.publicID
        defer { loadingQuizPublicID = nil }

        await state.openQuizFromLink(publicID: entry.quiz.publicID, token: nil)
    }
}
