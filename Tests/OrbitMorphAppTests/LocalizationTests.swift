import AppKit
import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class LocalizationTests: XCTestCase {
    func testExplicitLanguagesAndSystemResolution() {
        XCTAssertEqual(LocalizationManager.text("Settings…", language: .en, preferredLanguages: ["zh-Hans-CN"]), "Settings…")
        XCTAssertEqual(LocalizationManager.text("Settings…", language: .zhHans, preferredLanguages: ["en-US"]), "设置…")
        XCTAssertEqual(LocalizationManager.text("General", language: .system, preferredLanguages: ["zh-CN", "en-US"]), "通用")
        XCTAssertEqual(LocalizationManager.text("General", language: .system, preferredLanguages: ["de-DE", "en-US"]), "General")
        XCTAssertEqual(LocalizationManager.text("General", language: .system, preferredLanguages: ["zh-Hant-TW", "en-US"]), "General")
    }

    func testLiteralPercentDoesNotBecomeFormatSpecifier() {
        XCTAssertEqual(LocalizationManager.format("85%", language: .en, arguments: []), "85%")
    }

    @MainActor func testRenderOverridesRemainEphemeralWhenTutorialCloses() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "OrbitMorphRenderPreferences-\(UUID().uuidString)"))
        let store = SettingsStore(defaults: defaults)
        var original = AppSettings.default
        original.language = .en
        try store.save(original)
        let state = AppState(store: store, dependencies: .init(overrides: ["ffmpeg": nil, "magick": nil, "soffice": nil, "ebook-convert": nil, "7zz": nil]))
        state.applyPresentation(language: .zhHans, appearance: .solid)
        let manager = OnboardingManager(state: state, imageSampleURL: URL(fileURLWithPath: "/tmp/image.png"), videoSampleURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        manager.skip()
        XCTAssertEqual(try store.load(), original)
    }

    func testLegacySettingsKeepCustomShortcutsAndLanguageRoundTrips() throws {
        let legacy = Data(#"{"appearance":"solid","conversionModifier":"control+command","toolsModifier":"option+command","onboardingCompletedVersion":1}"#.utf8)
        var settings = try JSONDecoder().decode(AppSettings.self, from: legacy)
        XCTAssertEqual(settings.language, .system)
        XCTAssertEqual(settings.conversionModifier, "control+command")
        XCTAssertEqual(settings.toolsModifier, "option+command")
        XCTAssertEqual(settings.onboardingCompletedVersion, 1)
        settings.language = .zhHans
        let reloaded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(reloaded.language, .zhHans)
    }

    @MainActor func testLanguageChangeRefreshesDynamicStatusAndTutorialShortcut() throws {
        let state = try makeState()
        state.settings.conversionModifier = "control+command"
        state.message = "Converting 3 file(s)…"
        state.settings.language = .zhHans
        XCTAssertEqual(state.displayMessage, "正在转换 3 个文件…")
        XCTAssertTrue(state.L("Hold %@ while dragging the sample. Move across the wheel, then drop it on any format.", "⌃ Control + ⌘ Command").contains("⌃ Control + ⌘ Command"))
        XCTAssertEqual(state.L("spreadsheet"), "电子表格")
        XCTAssertEqual(state.L("Compress"), "压缩")
        state.settings.language = .en
        XCTAssertEqual(state.displayMessage, "Converting 3 file(s)…")
    }

    func testCatalogHasMatchingEnglishAndChineseValuesForEveryKey() throws {
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: LocalizationManager.catalogURL)) as? [String: Any]
        let strings = try XCTUnwrap(catalog?["strings"] as? [String: [String: Any]])
        XCTAssertGreaterThan(strings.count, 80)
        for (key, entry) in strings {
            let values = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            for language in ["en", "zh-Hans"] {
                let unit = try XCTUnwrap(values[language]?["stringUnit"] as? [String: String], "\(key): \(language)")
                XCTAssertFalse(unit["value"]?.isEmpty ?? true)
            }
        }
    }

    @MainActor private func makeState() throws -> AppState {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "OrbitMorphLocalization-\(UUID().uuidString)"))
        return AppState(store: .init(defaults: defaults), dependencies: .init(overrides: ["ffmpeg": nil, "magick": nil, "pandoc": nil, "soffice": nil, "ebook-convert": nil, "7zz": nil]))
    }
}
