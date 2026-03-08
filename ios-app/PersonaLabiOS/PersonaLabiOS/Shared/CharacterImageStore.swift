import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class CharacterImageStore: ObservableObject {
    static let shared = CharacterImageStore()

    @Published private(set) var imageDataByStorageKey: [String: Data] = [:]

    private let defaults = UserDefaults.standard
    private let globalKeyPrefix = "persona_lab.character_image.global."
    private let quizKeyPrefix = "persona_lab.character_image.quiz."
    private let legacyKeyPrefix = "persona_lab.character_image."

    private init() {
        loadFromDefaults()
    }

    func imageData(for resultCode: String, quizPublicID: String? = nil) -> Data? {
        let normalizedCode = normalizeResultCode(resultCode)
        if let quizPublicID,
           let scoped = imageDataByStorageKey[key(for: normalizedCode, quizPublicID: quizPublicID)] {
            return scoped
        }
        return imageDataByStorageKey[key(for: normalizedCode, quizPublicID: nil)]
    }

    func hasCustomImage(for resultCode: String, quizPublicID: String? = nil) -> Bool {
        let normalizedCode = normalizeResultCode(resultCode)
        return imageDataByStorageKey[key(for: normalizedCode, quizPublicID: quizPublicID)] != nil
    }

    func image(for resultCode: String, quizPublicID: String? = nil) -> Image? {
        guard let data = imageData(for: resultCode, quizPublicID: quizPublicID) else { return nil }

#if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
#elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
#else
        return nil
#endif
    }

    func setImageData(_ data: Data, for resultCode: String, quizPublicID: String? = nil) {
        let normalized = normalizeImageData(data) ?? data
        let storageKey = key(for: normalizeResultCode(resultCode), quizPublicID: quizPublicID)
        imageDataByStorageKey[storageKey] = normalized
        defaults.set(normalized, forKey: storageKey)
    }

    func removeImage(for resultCode: String, quizPublicID: String? = nil) {
        let storageKey = key(for: normalizeResultCode(resultCode), quizPublicID: quizPublicID)
        imageDataByStorageKey.removeValue(forKey: storageKey)
        defaults.removeObject(forKey: storageKey)
    }

    func removeAllImages(quizPublicID: String? = nil) {
        if let quizPublicID {
            let scopePrefix = scopedPrefix(for: quizPublicID)
            let scopedKeys = imageDataByStorageKey.keys.filter { $0.hasPrefix(scopePrefix) }
            for storageKey in scopedKeys {
                imageDataByStorageKey.removeValue(forKey: storageKey)
                defaults.removeObject(forKey: storageKey)
            }
            return
        }

        let globalKeys = imageDataByStorageKey.keys.filter { $0.hasPrefix(globalKeyPrefix) }
        for storageKey in globalKeys {
            imageDataByStorageKey.removeValue(forKey: storageKey)
            defaults.removeObject(forKey: storageKey)
        }
    }

    private func key(for resultCode: String, quizPublicID: String?) -> String {
        if let quizPublicID, !quizPublicID.isEmpty {
            return scopedPrefix(for: quizPublicID) + resultCode
        }
        return globalKeyPrefix + resultCode
    }

    private func scopedPrefix(for quizPublicID: String) -> String {
        "\(quizKeyPrefix)\(normalizeQuizPublicID(quizPublicID))."
    }

    private func normalizeQuizPublicID(_ quizPublicID: String) -> String {
        let tokens = quizPublicID.lowercased().split { !$0.isLetter && !$0.isNumber }
        let normalized = tokens.map(String.init).joined(separator: "_")
        return normalized.isEmpty ? "quiz" : normalized
    }

    private func normalizeResultCode(_ resultCode: String) -> String {
        let cleaned = resultCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        return cleaned.isEmpty ? "TYPE" : String(cleaned.prefix(16))
    }

    private func loadFromDefaults() {
        var loaded: [String: Data] = [:]

        for (storageKey, value) in defaults.dictionaryRepresentation() {
            guard let data = value as? Data else { continue }
            if storageKey.hasPrefix(globalKeyPrefix) || storageKey.hasPrefix(quizKeyPrefix) {
                loaded[storageKey] = data
            }
        }

        let legacyCodes = ResultCodeEngine
            .allCodes(axisDefinitions: AxisDefinition.defaultSet())
            .map { $0.lowercased() }

        for code in legacyCodes {
            let legacyKey = legacyKeyPrefix + code
            guard let legacyData = defaults.data(forKey: legacyKey) else { continue }

            let migratedKey = key(for: code.uppercased(), quizPublicID: nil)
            if loaded[migratedKey] == nil {
                loaded[migratedKey] = legacyData
                defaults.set(legacyData, forKey: migratedKey)
            }
            defaults.removeObject(forKey: legacyKey)
        }

        imageDataByStorageKey = loaded
    }

    private func normalizeImageData(_ data: Data) -> Data? {
#if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: 0.84)
#else
        return data
#endif
    }
}
