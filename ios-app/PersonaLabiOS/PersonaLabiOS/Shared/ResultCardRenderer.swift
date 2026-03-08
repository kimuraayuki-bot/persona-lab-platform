import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ResultCardView: View {
    let result: DiagnosisResult
    var avatarImageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DIAGNOSIS RESULT")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))

                    Text(result.resultCode)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    if !result.roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(result.roleName)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.95))
                    }

                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.95))
                }

                Spacer(minLength: 12)

                avatarView
            }

            Divider()
                .overlay(Color.white.opacity(0.4))

            HStack(spacing: 12) {
                axisPill(label: "EI", value: result.axisScore.ei)
                axisPill(label: "SN", value: result.axisScore.sn)
                axisPill(label: "TF", value: result.axisScore.tf)
                axisPill(label: "JP", value: result.axisScore.jp)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PopTheme.accent, PopTheme.accentAlt],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var avatarView: some View {
        if let image = decodedImage {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                }
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.95))
                        Text(result.resultCode)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                }
        }
    }

    private var decodedImage: Image? {
        guard let avatarImageData else { return nil }

#if canImport(UIKit)
        guard let uiImage = UIImage(data: avatarImageData) else { return nil }
        return Image(uiImage: uiImage)
#elseif canImport(AppKit)
        guard let nsImage = NSImage(data: avatarImageData) else { return nil }
        return Image(nsImage: nsImage)
#else
        return nil
#endif
    }

    private func axisPill(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(Color.white.opacity(0.85))
            Text("\(value)")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.22), in: Capsule())
    }
}

@MainActor
enum ResultCardRenderer {
    static func makeImage(result: DiagnosisResult, avatarImageData: Data? = nil, scale: CGFloat = 2.0) -> Image? {
        let renderer = ImageRenderer(content: ResultCardView(result: result, avatarImageData: avatarImageData).frame(width: 360, height: 280))
        renderer.scale = scale

#if canImport(UIKit)
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
#else
        return nil
#endif
    }

    static func makeUIImage(result: DiagnosisResult, avatarImageData: Data? = nil, scale: CGFloat = 2.0) -> Any? {
#if canImport(UIKit)
        let renderer = ImageRenderer(content: ResultCardView(result: result, avatarImageData: avatarImageData).frame(width: 360, height: 280))
        renderer.scale = scale
        return renderer.uiImage
#else
        return nil
#endif
    }
}
