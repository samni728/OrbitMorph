import AppKit
import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class SettingsFormatTests: XCTestCase {
    @MainActor func testCapabilityProbesFinishBeforeSettingsViewQueries() throws {
        let suite = "OrbitMorphDiscovery-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphDiscovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("ffmpeg")
        let events = root.appendingPathComponent("events.txt")
        let quotedPath = "'" + events.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        try "#!/bin/sh\nprintf 'probe\\n' >> \(quotedPath)\nexit 1\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let dependencies = DependencyResolver(overrides: ["ffmpeg": executable.path, "magick": nil])
        let state = AppState(store: .init(defaults: defaults), dependencies: dependencies)
        let discovered = try String(contentsOf: events, encoding: .utf8)
        XCTAssertFalse(discovered.isEmpty)
        _ = state.outputFormats
        _ = state.policy.isSupported(source: .wmv, target: .mp4)
        _ = state.policy.isSupported(source: .wav, target: .wma)
        _ = state.policy.isSupported(source: .svg, target: .png)
        XCTAssertEqual(try String(contentsOf: events, encoding: .utf8), discovered,
                       "UI capability reads must not start subprocesses while SwiftUI is rendering")
    }

    @MainActor func testSubtitleSettingsOfferNativeTargetsAndExcludeSVGOutput() {
        let suite = "OrbitMorphSubtitleFormats-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(store: .init(defaults: defaults))
        XCTAssertTrue(state.outputFormats.contains(.srt))
        XCTAssertTrue(state.outputFormats.contains(.vtt))
        XCTAssertFalse(state.outputFormats.contains(.svg))
    }

    @MainActor func testSubtitleOutputFolderTakesPriorityOverDefaultFolder() throws {
        let suite = "OrbitMorphSubtitleFolder-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphFolders-\(UUID().uuidString)")
        let defaultFolder = root.appendingPathComponent("default")
        let subtitleFolder = root.appendingPathComponent("字幕")
        try FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subtitleFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let state = AppState(store: .init(defaults: defaults))
        state.settings.saveBesideSource = false
        state.settings.outputFolders = [
            try FolderBookmarkStore.makeRecord(category: .unknown, url: defaultFolder),
            try FolderBookmarkStore.makeRecord(category: .subtitle, url: subtitleFolder),
        ]
        XCTAssertEqual(try state.outputFolder(for: .subtitle)?.standardizedFileURL.path, subtitleFolder.standardizedFileURL.path)
        XCTAssertEqual(try state.outputFolder(for: .document)?.standardizedFileURL.path, defaultFolder.standardizedFileURL.path)
        state.settings.saveBesideSource = true
        XCTAssertNil(try state.outputFolder(for: .subtitle))
    }

    @MainActor func testOutputSettingsDoNotOfferInputOnlyArchives() {
        let suite = "OrbitMorphFormats-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(store: .init(defaults: defaults))
        XCTAssertFalse(state.outputFormats.contains(.rar))
        XCTAssertFalse(state.outputFormats.contains(.gz))
        XCTAssertTrue(state.outputFormats.contains(.png))
    }
}
