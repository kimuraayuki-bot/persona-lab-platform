import SwiftUI
import PersonaLabCore

struct ResultView: View {
    @EnvironmentObject private var state: AppState
    let result: DiagnosisResult

    @State private var isShowingSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ResultCardView(result: result)

                Text("タイプ: \(result.type.title)")
                    .font(.title2.bold())
                Text(ResultProfileStore.all[result.type]?.summary ?? "")
                    .foregroundStyle(.secondary)

                Button("結果をSNSで共有") {
                    Task { await prepareShare() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("結果")
        .sheet(isPresented: $isShowingSheet) {
            ShareSheet(items: shareItems)
        }
    }

    private func prepareShare() async {
        await state.buildShareMessage(for: result)

        guard let payload = state.sharePayload else { return }
        var items: [Any] = ["\(payload.message)\n\(payload.shareURL.absoluteString)"]

        if let image = ResultCardRenderer.makeUIImage(result: result) {
            items.insert(image, at: 0)
        }

        shareItems = items
        isShowingSheet = true
    }
}
