import Foundation
import OrbitMorphCore

enum LocalizationManager {
    static let catalogURL: URL = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings")
        ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Localizable.xcstrings")
    private struct Catalog: Decodable { let strings: [String: Entry] }
    private struct Entry: Decodable { let localizations: [String: Translation] }
    private struct Translation: Decodable { let stringUnit: Unit }
    private struct Unit: Decodable { let value: String }
    private static let translations: [String: [String: String]] = {
        guard let data = try? Data(contentsOf: catalogURL), let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else { return [:] }
        return catalog.strings.mapValues { $0.localizations.mapValues { $0.stringUnit.value } }
    }()

    static func resolved(_ language: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard language == .system else { return language }
        for value in preferredLanguages {
            let identifier = value.lowercased().replacingOccurrences(of: "_", with: "-")
            if identifier.hasPrefix("zh-hant") || identifier.hasPrefix("zh-tw") || identifier.hasPrefix("zh-hk") || identifier.hasPrefix("zh-mo") { continue }
            if identifier == "zh" || identifier.hasPrefix("zh-hans") || identifier.hasPrefix("zh-cn") || identifier.hasPrefix("zh-sg") { return .zhHans }
            if identifier.hasPrefix("en") { return .en }
        }
        return .en
    }

    static func text(_ key: String, language: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        translations[key]?[resolved(language, preferredLanguages: preferredLanguages).rawValue] ?? translations[key]?["en"] ?? key
    }

    static func format(_ key: String, language: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages, arguments: [CVarArg]) -> String {
        let value = text(key, language: language, preferredLanguages: preferredLanguages)
        guard !arguments.isEmpty else { return value }
        return String(format: value, locale: Locale(identifier: resolved(language, preferredLanguages: preferredLanguages).rawValue), arguments: arguments)
    }

    /// Resolve canonical status text at display time so an existing job message also
    /// changes language immediately. Backend diagnostic details remain intact.
    static func status(_ raw: String, language: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        for (prefix, key) in [("Could not save settings: ", "Could not save settings: %@"), ("Login item: ", "Login item: %@"), ("Folder access: ", "Folder access: %@"), ("Conversion failed: ", "Conversion failed: %@")] where raw.hasPrefix(prefix) {
            return format(key, language: language, preferredLanguages: preferredLanguages, arguments: [String(raw.dropFirst(prefix.count))])
        }
        if raw.hasPrefix("Converting "), let count = Int(raw.dropFirst("Converting ".count).split(separator: " ").first ?? "") {
            return format("Converting %d file(s)…", language: language, preferredLanguages: preferredLanguages, arguments: [count])
        }
        if raw.hasPrefix("Converted "), let count = Int(raw.dropFirst("Converted ".count).split(separator: " ").first ?? ""), let separator = raw.range(of: " · ") {
            return format("Converted %d output(s) · %@", language: language, preferredLanguages: preferredLanguages, arguments: [count, String(raw[separator.upperBound...])])
        }
        return text(raw, language: language, preferredLanguages: preferredLanguages)
    }
}
