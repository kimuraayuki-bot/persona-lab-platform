import SwiftUI

struct ReportQuizSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: AppState

    let quizPublicID: String
    let quizTitle: String
    let source: QuizReportSource
    let pageURL: String?
    var onSubmitted: (() -> Void)?

    @State private var reason: QuizReportReason = .illegal
    @State private var details = ""
    @State private var reporterEmail = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("対象") {
                    LabeledContent("診断名", value: quizTitle)
                    LabeledContent("公開ID", value: quizPublicID)
                    if let pageURL, !pageURL.isEmpty {
                        LabeledContent("対象URL", value: pageURL)
                    }
                }

                Section {
                    Picker("問題の種類", selection: $reason) {
                        ForEach(QuizReportReason.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                } header: {
                    Text("理由")
                } footer: {
                    Text("問題箇所や背景があれば記載してください。空欄でも送信できます。")
                }

                Section("返信用メールアドレス") {
                    TextField("任意。必要な場合のみ返信します。", text: $reporterEmail)
                        .textInputAutocapitalization(.never)
#if os(iOS)
                        .keyboardType(.emailAddress)
#endif
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("診断を通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSubmitting ? "送信中..." : "送信") {
                        submit()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
        .onAppear {
            if reporterEmail.isEmpty {
                reporterEmail = state.currentUserEmail ?? ""
            }
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = reporterEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            defer { isSubmitting = false }

            do {
                try await state.apiClient.submitQuizReport(
                    payload: SubmitQuizReportRequest(
                        quizPublicID: quizPublicID,
                        source: source,
                        reason: reason,
                        details: trimmedDetails,
                        reporterEmail: trimmedEmail.isEmpty ? nil : trimmedEmail,
                        pageURL: pageURL,
                        appVersion: appVersion
                    )
                )
                onSubmitted?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var appVersion: String? {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, build) {
        case let (.some(shortVersion), .some(build)) where !shortVersion.isEmpty && !build.isEmpty:
            return "\(shortVersion) (\(build))"
        case let (.some(shortVersion), _):
            return shortVersion
        case let (_, .some(build)):
            return build
        default:
            return nil
        }
    }
}
