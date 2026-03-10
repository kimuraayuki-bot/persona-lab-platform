import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ResultView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var imageStore = CharacterImageStore.shared

    let result: DiagnosisResult

    @State private var isShowingSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingCharacterImages = false
    @State private var isPreparingShare = false
    @State private var showingReportSheet = false
    @State private var helperMessage: String?

    private var currentQuiz: Quiz? {
        if let activeQuiz = state.activeQuiz, activeQuiz.id == result.quizID {
            return activeQuiz
        }
        return state.quizzes.first(where: { $0.id == result.quizID })
    }

    private var quizPublicID: String? {
        currentQuiz?.publicID
    }

    private var quizTitle: String {
        currentQuiz?.title ?? "診断"
    }

    private var profilesForQuiz: [QuizResultProfile] {
        if let quiz = currentQuiz {
            return quiz.resultProfiles
        }
        return QuizResultProfile.normalized([], axisDefinitions: AxisDefinition.defaultSet())
    }

    private var axisDefinitionsForQuiz: [AxisDefinition] {
        currentQuiz?.axisDefinitions ?? AxisDefinition.defaultSet()
    }

    private var avatarImageData: Data? {
        imageStore.imageData(for: result.resultCode, quizPublicID: quizPublicID)
    }

    private var shouldShowReportAction: Bool {
        guard let currentQuiz else { return false }
        return currentQuiz.creatorID == nil || currentQuiz.creatorID != state.currentUserID
    }

    private var reportQuiz: Quiz? {
        guard shouldShowReportAction else { return nil }
        return currentQuiz
    }

    private var reportPageURL: String? {
        guard let currentQuiz else { return nil }
        var url = URL(string: "myapp://quiz/\(currentQuiz.publicID)")!
        if let activeShareToken = state.activeShareToken, !activeShareToken.isEmpty {
            url = url.appending(queryItems: [URLQueryItem(name: "token", value: activeShareToken)])
        }
        return url.absoluteString
    }

    var body: some View {
        ZStack {
            PopBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ResultCardView(
                        result: result,
                        axisDefinitions: axisDefinitionsForQuiz,
                        avatarImageData: avatarImageData
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("結果コード: \(result.resultCode)")
                            .font(.title2.bold())
                            .foregroundStyle(PopTheme.textPrimary)

                        if !result.roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("役割名: \(result.roleName)")
                                .font(.headline)
                                .foregroundStyle(PopTheme.textPrimary)
                        }

                        Text(result.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        if !result.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Divider()
                            Text(result.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Text("この結果カード画像はSNS共有時にも利用されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .popCard(cornerRadius: 18)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button("この診断のタイプ画像を設定") {
                                showingCharacterImages = true
                            }
                            .buttonStyle(.bordered)

                            Button("結果をSNSで共有") {
                                Task { await prepareShare() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PopTheme.accent)
                            .disabled(isPreparingShare)
                        }

                        Button("共有文をコピー") {
                            Task { await copyShareText() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPreparingShare)

                        if shouldShowReportAction {
                            Button("この診断を通報") {
                                showingReportSheet = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(isPreparingShare)
                        }

                        if isPreparingShare {
                            ProgressView("共有データを準備中...")
                                .font(.footnote)
                        }

                        if let helperMessage {
                            Text(helperMessage)
                                .font(.footnote)
                                .foregroundStyle(PopTheme.accentAlt)
                        }
                    }
                    .popCard(cornerRadius: 18)

                    AdMobBannerView(placement: .result)
                }
                .padding(16)
            }
        }
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingCharacterImages) {
            NavigationStack {
                if let quizPublicID {
                    CharacterImageSettingsView(
                        quizPublicID: quizPublicID,
                        quizTitle: quizTitle,
                        profiles: profilesForQuiz
                    )
                } else {
                    CharacterImageSettingsView(profiles: profilesForQuiz)
                }
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            if let reportQuiz {
                ReportQuizSheet(
                    quizPublicID: reportQuiz.publicID,
                    quizTitle: reportQuiz.title,
                    source: .iosResult,
                    pageURL: reportPageURL
                ) {
                    helperMessage = "通報を送信しました。確認後に必要があれば掲載停止します。"
                }
            }
        }
    }

    private func prepareShare() async {
        isPreparingShare = true
        helperMessage = nil
        defer { isPreparingShare = false }

        guard let payload = await buildSharePayload() else { return }
        var items: [Any] = ["\(payload.message)\n\(payload.shareURL.absoluteString)"]

        if let image = ResultCardRenderer.makeUIImage(
            result: result,
            axisDefinitions: axisDefinitionsForQuiz,
            avatarImageData: avatarImageData
        ) {
            items.insert(image, at: 0)
        }

        shareItems = items
        isShowingSheet = true
    }

    private func copyShareText() async {
        isPreparingShare = true
        helperMessage = nil
        defer { isPreparingShare = false }

        guard let payload = await buildSharePayload() else { return }
        let text = "\(payload.message)\n\(payload.shareURL.absoluteString)"

#if canImport(UIKit)
        UIPasteboard.general.string = text
#endif
        helperMessage = "共有文をコピーしました。"
    }

    private func buildSharePayload() async -> SharePayload? {
        await state.buildShareMessage(for: result)
        guard let payload = state.sharePayload else {
            helperMessage = "共有リンクの作成に失敗しました。"
            return nil
        }
        return payload
    }
}
