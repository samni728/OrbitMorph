import XCTest
@testable import OrbitMorphCore

final class DragLogicTests: XCTestCase {
    func testUnrelatedMouseDragIsIgnored() {
        var state = GlobalDragStateMachine()
        XCTAssertEqual(state.handle(.dragged(shift: false, option: false, sourceIsFinder: true)), .none)
        XCTAssertEqual(state.handle(.dragged(shift: true, option: false, sourceIsFinder: false)), .none)
        XCTAssertEqual(state.phase, .idle)
    }

    func testShiftArmsConversionAndOptionShiftPrefersTools() {
        var conversion = GlobalDragStateMachine()
        XCTAssertEqual(conversion.handle(.dragged(shift: true, option: false, sourceIsFinder: true)), .show(.conversion))
        XCTAssertEqual(conversion.phase, .armed(.conversion))

        var tools = GlobalDragStateMachine()
        XCTAssertEqual(tools.handle(.dragged(shift: true, option: true, sourceIsFinder: true)), .show(.tools))
        XCTAssertEqual(tools.phase, .armed(.tools))
    }

    func testMouseUpCancelsArmedSessionWithoutFiles() {
        var state = GlobalDragStateMachine()
        _ = state.handle(.dragged(shift: true, option: false, sourceIsFinder: true))
        XCTAssertEqual(state.handle(.mouseUp), .cancel)
        XCTAssertEqual(state.phase, .idle)
    }

    func testResolvedFilesKeepSessionActiveUntilDrop() {
        var state = GlobalDragStateMachine()
        _ = state.handle(.dragged(shift: true, option: false, sourceIsFinder: true))
        XCTAssertEqual(state.handle(.filesResolved(count: 2)), .filesReady)
        XCTAssertEqual(state.phase, .ready(.conversion))
        XCTAssertEqual(state.handle(.dropCompleted), .finish)
        XCTAssertEqual(state.phase, .idle)
    }

    func testToolRegistryFiltersByInputKind() {
        let imageActions = ToolRegistry.commonActions(for: [.png, .jpg])
        XCTAssertTrue(imageActions.contains(.resizeImage))
        XCTAssertTrue(imageActions.contains(.stripMetadata))
        XCTAssertFalse(imageActions.contains(.extractAudio))

        let videoActions = ToolRegistry.commonActions(for: [.mov])
        XCTAssertTrue(videoActions.contains(.extractAudio))
        XCTAssertTrue(videoActions.contains(.makeGIF))
    }

    func testValidatedFileURLsRejectMissingAndNonFileURLs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let real = root.appendingPathComponent("real.png")
        try Data([1]).write(to: real)
        let missing = root.appendingPathComponent("missing.png")
        let result = ValidatedFileURLs.resolve([real, missing, URL(string: "https://example.com/a.png")!])
        XCTAssertEqual(result, [real])
    }
}
