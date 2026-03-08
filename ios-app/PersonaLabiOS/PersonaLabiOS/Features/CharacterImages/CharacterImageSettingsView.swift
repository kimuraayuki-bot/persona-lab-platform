import SwiftUI

#if canImport(PhotosUI)
import PhotosUI
#endif

struct CharacterImageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var imageStore = CharacterImageStore.shared

    let quizPublicID: String?
    let quizTitle: String?

#if canImport(PhotosUI)
    @State private var isShowingPicker = false
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var editingType: MBTIType?
#endif

    init(quizPublicID: String? = nil, quizTitle: String? = nil) {
        self.quizPublicID = quizPublicID
        self.quizTitle = quizTitle
    }

    private var isScopedSetting: Bool {
        quizPublicID != nil
    }

    private var configuredCount: Int {
        MBTIType.allCases.filter { imageStore.hasCustomImage(for: $0, quizPublicID: quizPublicID) }.count
    }

    private var subtitleText: String {
        if isScopedSetting {
            if let quizTitle, !quizTitle.isEmpty {
                return "対象: \(quizTitle)（この診断専用）"
            }
            return "対象: この診断専用"
        }
        return "対象: 全診断の共通設定"
    }

    var body: some View {
        ZStack {
            PopBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タイプごとにキャラ画像を設定")
                            .font(.title3.bold())
                            .foregroundStyle(PopTheme.textPrimary)

                        Text(subtitleText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if isScopedSetting {
                            Text("未設定タイプは共通設定、さらに未設定ならデフォルト画像を使用します。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("結果カードとシェア画像に反映されます（端末内保存）")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Text("この画面で設定済み: \(configuredCount) / \(MBTIType.allCases.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .popCard(cornerRadius: 18)

                    if configuredCount > 0 {
                        Button(role: .destructive) {
                            imageStore.removeAllImages(quizPublicID: quizPublicID)
                        } label: {
                            Label(isScopedSetting ? "この診断の画像を全リセット" : "共通画像を全リセット", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(MBTIType.allCases, id: \.self) { type in
                        row(for: type)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("キャラ画像")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") { dismiss() }
            }
        }
#if canImport(PhotosUI)
        .photosPicker(isPresented: $isShowingPicker, selection: $selectedPickerItem, matching: .images)
        .onChange(of: selectedPickerItem) { _, newValue in
            guard let newValue, let targetType = editingType else { return }

            Task {
                let data = try? await newValue.loadTransferable(type: Data.self)
                if let data {
                    await MainActor.run {
                        imageStore.setImageData(data, for: targetType, quizPublicID: quizPublicID)
                    }
                }

                await MainActor.run {
                    selectedPickerItem = nil
                    editingType = nil
                }
            }
        }
#endif
    }

    @ViewBuilder
    private func row(for type: MBTIType) -> some View {
        let hasScopedCustom = imageStore.hasCustomImage(for: type, quizPublicID: quizPublicID)
        let hasGlobalCustom = imageStore.hasCustomImage(for: type, quizPublicID: nil)
        let isUsingGlobalFallback = isScopedSetting && !hasScopedCustom && hasGlobalCustom

        HStack(spacing: 12) {
            avatarPreview(for: type)

            VStack(alignment: .leading, spacing: 4) {
                Text(type.title)
                    .font(.headline)
                Text(ResultProfileStore.all[type]?.summary ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if hasScopedCustom {
                    Text(isScopedSetting ? "この診断専用画像を使用中" : "共通画像を使用中")
                        .font(.caption2)
                        .foregroundStyle(PopTheme.accentAlt)
                } else if isUsingGlobalFallback {
                    Text("共通画像を使用中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("デフォルト画像を使用")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button("選択") {
                    openPicker(for: type)
                }
                .buttonStyle(.borderedProminent)
                .tint(PopTheme.accent)

                Button("削除", role: .destructive) {
                    imageStore.removeImage(for: type, quizPublicID: quizPublicID)
                }
                .buttonStyle(.bordered)
                .disabled(!hasScopedCustom)
            }
        }
        .popCard(cornerRadius: 18, padding: 12)
    }

    @ViewBuilder
    private func avatarPreview(for type: MBTIType) -> some View {
        if let image = imageStore.image(for: type, quizPublicID: quizPublicID) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white, lineWidth: 2)
                }
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [PopTheme.accent.opacity(0.78), PopTheme.accentAlt.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 66, height: 66)
                .overlay {
                    VStack(spacing: 2) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.92))
                        Text(type.title)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
        }
    }

    private func openPicker(for type: MBTIType) {
#if canImport(PhotosUI)
        editingType = type
        isShowingPicker = true
#endif
    }
}
