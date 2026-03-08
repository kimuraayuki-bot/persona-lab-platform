import SwiftUI
import PersonaLabCore

#if canImport(UIKit)
import UIKit
#endif

struct ResultCardView: View {
    let result: DiagnosisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("診断結果")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(result.type.title)
                .font(.system(size: 42, weight: .black, design: .rounded))
            Text(ResultProfileStore.all[result.type]?.summary ?? "")
                .font(.body)
            Divider()
            Text("EI: \(result.axisScore.ei) / SN: \(result.axisScore.sn)")
            Text("TF: \(result.axisScore.tf) / JP: \(result.axisScore.jp)")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.mint.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}

@MainActor
enum ResultCardRenderer {
    static func makeImage(result: DiagnosisResult, scale: CGFloat = 2.0) -> Image? {
        let renderer = ImageRenderer(content: ResultCardView(result: result).frame(width: 360, height: 280))
        renderer.scale = scale

#if canImport(UIKit)
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
#else
        return nil
#endif
    }

    static func makeUIImage(result: DiagnosisResult, scale: CGFloat = 2.0) -> Any? {
#if canImport(UIKit)
        let renderer = ImageRenderer(content: ResultCardView(result: result).frame(width: 360, height: 280))
        renderer.scale = scale
        return renderer.uiImage
#else
        return nil
#endif
    }
}
