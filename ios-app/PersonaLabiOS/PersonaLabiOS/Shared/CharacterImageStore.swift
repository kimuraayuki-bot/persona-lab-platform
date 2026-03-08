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

    func imageData(for type: MBTIType, quizPublicID: String? = nil) -> Data? {
        if let quizPublicID, let scoped = imageDataByStorageKey[key(for: type, quizPublicID: quizPublicID)] {
            return scoped
        }
        return imageDataByStorageKey[key(for: type, quizPublicID: nil)]
    }

    func hasCustomImage(for type: MBTIType, quizPublicID: String? = nil) -> Bool {
        imageDataByStorageKey[key(for: type, quizPublicID: quizPublicID)] != nil
    }

    func image(for type: MBTIType, quizPublicID: String? = nil) -> Image? {
        guard let data = imageData(for: type, quizPublicID: quizPublicID) else { return nil }

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

    func setImageData(_ data: Data, for type: MBTIType, quizPublicID: String? = nil) {
        let normalized = normalizeImageData(data) ?? data
        let storageKey = key(for: type, quizPublicID: quizPublicID)
        imageDataByStorageKey[storageKey] = normalized
        defaults.set(normalized, forKey: storageKey)
    }

    func removeImage(for type: MBTIType, quizPublicID: String? = nil) {
        let storageKey = key(for: type, quizPublicID: quizPublicID)
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

        for type in MBTIType.allCases {
            let storageKey = key(for: type, quizPublicID: nil)
            imageDataByStorageKey.removeValue(forKey: storageKey)
            defaults.removeObject(forKey: storageKey)
        }
    }

    private func key(for type: MBTIType, quizPublicID: String?) -> String {
        if let quizPublicID, !quizPublicID.isEmpty {
            return scopedPrefix(for: quizPublicID) + type.rawValue
        }
        return globalKeyPrefix + type.rawValue
    }

    private func scopedPrefix(for quizPublicID: String) -> String {
        "\(quizKeyPrefix)\(normalizeQuizPublicID(quizPublicID))."
    }

    private func normalizeQuizPublicID(_ quizPublicID: String) -> String {
        let tokens = quizPublicID.lowercased().split { !$0.isLetter && !$0.isNumber }
        let normalized = tokens.map(String.init).joined(separator: "_")
        return normalized.isEmpty ? "quiz" : normalized
    }

    private func loadFromDefaults() {
        var loaded: [String: Data] = [:]

        for (storageKey, value) in defaults.dictionaryRepresentation() {
            guard let data = value as? Data else { continue }
            if storageKey.hasPrefix(globalKeyPrefix) || storageKey.hasPrefix(quizKeyPrefix) {
                loaded[storageKey] = data
            }
        }

        for type in MBTIType.allCases {
            let legacyKey = legacyKeyPrefix + type.rawValue
            guard let legacyData = defaults.data(forKey: legacyKey) else { continue }

            let migratedKey = key(for: type, quizPublicID: nil)
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
