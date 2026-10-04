import XCTest
@testable import OrbitMorphCore

final class SettingsWorkflowTests: XCTestCase {
    func testFileDragGateRejectsFinderSelectionAndStalePasteboard() {
        var gate = FileDragPasteboardGate()
        gate.begin(changeCount: 10)
        XCTAssertFalse(gate.accepts(changeCount: 10, validatedFileCount: 1))
        XCTAssertFalse(gate.accepts(changeCount: 11, validatedFileCount: 0))
        XCTAssertTrue(gate.accepts(changeCount: 11, validatedFileCount: 1))
        gate.end()
        XCTAssertFalse(gate.accepts(changeCount: 11, validatedFileCount: 1))
        gate.begin(changeCount: 11)
        XCTAssertFalse(gate.accepts(changeCount: 11, validatedFileCount: 1))
        XCTAssertTrue(gate.accepts(changeCount: 12, validatedFileCount: 1))
    }

    func testArchiveToolUsesNativeExtractorWithoutSevenZip() {
        let deps = DependencyResolver(overrides: ["7zz": nil])
        XCTAssertTrue(ToolRegistry.commonActions(for: [.zip], dependencies: deps).contains(.unarchive))
        XCTAssertTrue(ToolRegistry.commonActions(for: [.tar, .tgz], dependencies: deps).contains(.unarchive))
        XCTAssertFalse(ToolRegistry.commonActions(for: [.rar], dependencies: deps).contains(.unarchive))
    }

    func testDisabledRouteAndUnknownFileAffectWheelTargets() {
        let policy = CompatibilityPolicy(disabledRoutes: [.init(source: .png, target: .jpg)])
        XCTAssertFalse(policy.commonTargets(for: [URL(fileURLWithPath: "/tmp/a.png")]).contains(.jpg))
        XCTAssertTrue(policy.commonTargets(for: [URL(fileURLWithPath: "/tmp/a.png"), URL(fileURLWithPath: "/tmp/b.unknown")]).isEmpty)
    }

    func testConfiguredModifierMatchesExactly() {
        var settings = AppSettings.default
        settings.conversionModifier = "control"
        settings.toolsModifier = "control+shift"
        XCTAssertEqual(ModifierMatcher.mode(shift: false, option: false, control: true, command: false, settings: settings), .conversion)
        XCTAssertEqual(ModifierMatcher.mode(shift: true, option: false, control: true, command: false, settings: settings), .tools)
        XCTAssertNil(ModifierMatcher.mode(shift: false, option: false, control: true, command: true, settings: settings))
    }

    func testOutputFolderBookmarksPersistWithOtherSettings() throws {
        var settings = AppSettings.default
        settings.saveBesideSource = false
        settings.outputFolders = [.init(category: .image, displayPath: "/tmp/export", bookmarkData: Data([1, 2]))]
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.outputFolders, settings.outputFolders)
        XCTAssertFalse(restored.saveBesideSource)
    }

    func testOlderPartialSettingsKeepDefaultsForNewFields() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appearance":"solid"}"#.utf8))
        XCTAssertEqual(settings.appearance, .solid)
        XCTAssertEqual(settings.conversionModifier, "shift")
        XCTAssertTrue(settings.saveBesideSource)
    }

    func testAbandonedReadyDragDoesNotPreventNextDrag() {
        var state = GlobalDragStateMachine()
        _ = state.handle(.dragged(shift: true, option: false, sourceIsFinder: true))
        _ = state.handle(.filesResolved(count: 1))
        XCTAssertEqual(state.handle(.mouseUp), .cancel)
        XCTAssertEqual(state.phase, .idle)
        XCTAssertEqual(state.handle(.dragged(shift: true, option: true, sourceIsFinder: true)), .show(.tools))
    }

    func testModifierChangeSwitchesExistingDragWheel() {
        var state = GlobalDragStateMachine()
        _ = state.handle(.dragged(shift: true, option: false, sourceIsFinder: true))
        XCTAssertEqual(state.handle(.dragged(shift: true, option: true, sourceIsFinder: true)), .show(.tools))
        XCTAssertEqual(state.phase, .armed(.tools))
        XCTAssertEqual(state.handle(.dragged(shift: false, option: false, sourceIsFinder: true)), .cancel)
    }

    func testDocumentWheelDoesNotOfferUnimplementedImageTools() {
        let actions = ToolRegistry.commonActions(for: [.docx])
        XCTAssertFalse(actions.contains(.compress))
        XCTAssertFalse(actions.contains(.stripMetadata))
        XCTAssertFalse(actions.contains(.pdfMerge))
        XCTAssertTrue(actions.contains(.archive))
        XCTAssertFalse(ToolRegistry.commonActions(for: [.pdf]).contains(.pdfMerge))
        XCTAssertTrue(ToolRegistry.commonActions(for: [.pdf, .pdf]).contains(.pdfMerge))
    }
}
