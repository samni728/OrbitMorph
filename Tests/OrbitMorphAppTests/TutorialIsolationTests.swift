import AppKit
import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class TutorialIsolationTests: XCTestCase {
    @MainActor func testMenuOffersSettingsAndOutputsWithoutAnyDropOrTutorialEntry() throws {
        let state = try makeState()
        let menu = StatusMenuFactory.makeMenu(state: state, target: NSObject())
        let actions = Set(menu.items.compactMap { $0.action.map(NSStringFromSelector) })
        XCTAssertEqual(actions, ["showSettings", "showAbout", "revealOutputs", "quit"])
        XCTAssertFalse(menu.items.contains { $0.keyEquivalent == "d" || $0.keyEquivalent == "o" })
    }

    @MainActor func testSimulationDisplaysRealTargetsAndRecordsResultWithoutWritingAnOutput() throws {
        let state = try makeState()
        let image = SampleResources.imageURL
        let manager = OnboardingManager(state: state, imageSampleURL: image, videoSampleURL: SampleResources.videoURL)
        let directory = image.deletingLastPathComponent()
        let before = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        let model = manager.makeDemoModel()
        XCTAssertTrue(model.items.contains { $0.value == .format(.jpg) })
        XCTAssertFalse(model.items.contains { $0.value == .format(.mp4) })
        manager.completeDemo(item: WheelDisplayItem(value: .format(.jpg)))
        XCTAssertTrue(manager.canAdvance)
        XCTAssertEqual(manager.demoResult, "OrbitMorph-Sample.jpg")
        XCTAssertFalse(state.isBusy)
        XCTAssertTrue(state.lastOutputs.isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), before)
    }

    @MainActor func testToolsSimulationDoesNotCompleteConversionLessonAndInvalidTargetIsRejected() throws {
        let state = try makeState()
        let manager = OnboardingManager(state: state, imageSampleURL: SampleResources.imageURL, videoSampleURL: SampleResources.videoURL)
        manager.completeDemo(item: .init(value: .tool(.archive)))
        XCTAssertFalse(manager.canAdvance)
        manager.completeDemo(item: .init(value: .format(.mp4)))
        XCTAssertFalse(manager.canAdvance)
        manager.completeDemo(item: .init(value: .format(.jpg)))
        manager.next()
        XCTAssertNil(manager.demoResult)
        XCTAssertEqual(manager.makeDemoModel().mode, .tools)
        manager.completeDemo(item: .init(value: .format(.jpg)))
        XCTAssertFalse(manager.canAdvance)
    }

    @MainActor func testSampleDemoStaysInsideTutorialAndDoesNotModifySystemDragPasteboard() throws {
        _ = NSApplication.shared
        let state = try makeState()
        let manager = OnboardingManager(state: state, imageSampleURL: SampleResources.imageURL, videoSampleURL: SampleResources.videoURL)
        let view = TutorialDemoCanvas(manager: manager, frame: NSRect(x: 0, y: 0, width: 580, height: 240))
        let windowsBefore = Set(NSApp.windows.map(ObjectIdentifier.init))
        let dragChangeCount = NSPasteboard(name: .drag).changeCount
        // Mouse locations are in a window-less view's local coordinates here.
        view.mouseDown(with: try event(.leftMouseDown, at: .init(x: 88, y: 120), modifiers: .shift))
        view.mouseDragged(with: try event(.leftMouseDragged, at: .init(x: 420, y: 205), modifiers: .shift))
        XCTAssertTrue(view.isWheelVisible)
        XCTAssertEqual(NSPasteboard(name: .drag).changeCount, dragChangeCount)
        XCTAssertEqual(Set(NSApp.windows.map(ObjectIdentifier.init)), windowsBefore)
        view.mouseUp(with: try event(.leftMouseUp, at: .init(x: 420, y: 205), modifiers: .shift))
        XCTAssertTrue(manager.canAdvance)
        XCTAssertFalse(view.isWheelVisible)
        XCTAssertTrue(state.lastOutputs.isEmpty)
    }

    @MainActor func testDemoWithoutModifierDoesNotRevealWheelAndCenterReleaseDoesNotComplete() throws {
        _ = NSApplication.shared
        let state = try makeState()
        let manager = OnboardingManager(state: state, imageSampleURL: SampleResources.imageURL, videoSampleURL: SampleResources.videoURL)
        let view = TutorialDemoCanvas(manager: manager, frame: NSRect(x: 0, y: 0, width: 580, height: 240))
        view.mouseDown(with: try event(.leftMouseDown, at: .init(x: 88, y: 120), modifiers: []))
        view.mouseDragged(with: try event(.leftMouseDragged, at: .init(x: 420, y: 200), modifiers: []))
        XCTAssertFalse(view.isWheelVisible)
        view.mouseUp(with: try event(.leftMouseUp, at: .init(x: 420, y: 200), modifiers: []))
        XCTAssertFalse(manager.canAdvance)
        view.mouseDown(with: try event(.leftMouseDown, at: .init(x: 88, y: 120), modifiers: .shift))
        view.mouseDragged(with: try event(.leftMouseDragged, at: .init(x: 420, y: 120), modifiers: .shift))
        view.mouseUp(with: try event(.leftMouseUp, at: .init(x: 420, y: 120), modifiers: .shift))
        XCTAssertFalse(manager.canAdvance)
    }

    @MainActor func testDismissPersistsCompletionAndNativeTitlebarRemainsSeparateFromContent() throws {
        _ = NSApplication.shared
        let state = try makeState()
        let controller = TutorialWindowController(manager: .init(state: state, imageSampleURL: SampleResources.imageURL, videoSampleURL: SampleResources.videoURL), onOpenFolders: {})
        XCTAssertFalse(controller.window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(controller.window.isMovable)
        XCTAssertNotNil(controller.window.standardWindowButton(.closeButton))
        controller.show()
        controller.dismiss()
        XCTAssertFalse(controller.window.isVisible)
        XCTAssertEqual(StartupPresentationPolicy.initialWindow(settings: state.settings, arguments: []), .none)
    }

    @MainActor func testShowingTutorialImmediatelyPersistsSeenStateBeforeWindowCloses() throws {
        _ = NSApplication.shared
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "OrbitMorphSeen-\(UUID().uuidString)"))
        let store = SettingsStore(defaults: defaults)
        let state = AppState(store: store, dependencies: .init(overrides: ["ffmpeg": nil, "magick": nil]))
        let manager = OnboardingManager(state: state, imageSampleURL: SampleResources.imageURL, videoSampleURL: SampleResources.videoURL)
        let controller = TutorialWindowController(manager: manager, onOpenFolders: {})
        controller.show()
        defer { controller.dismiss() }
        XCTAssertTrue(controller.window.isVisible)
        XCTAssertEqual(StartupPresentationPolicy.initialWindow(settings: try store.load(), arguments: []), .none)
    }

    @MainActor func testWatchDemoUsesOnlyChildWheelAndNeverCreatesFilesOrPasteboardDrag() async throws {
        _ = NSApplication.shared
        let state = try makeState()
        let manager = OnboardingManager(state: state, imageSampleURL: SampleResources.imageURL, videoSampleURL: SampleResources.videoURL)
        let canvas = TutorialDemoCanvas(manager: manager, frame: NSRect(x: 0, y: 0, width: 580, height: 240))
        let window = NSWindow(contentRect: canvas.bounds, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = canvas; window.orderFront(nil)
        defer { window.close() }
        let windows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let dragCount = NSPasteboard(name: .drag).changeCount
        manager.requestPreview(); canvas.refresh()
        XCTAssertTrue(canvas.isWheelVisible)
        try await Task.sleep(for: .milliseconds(1300))
        XCTAssertTrue(manager.canAdvance)
        XCTAssertNotNil(manager.demoResult)
        XCTAssertEqual(NSPasteboard(name: .drag).changeCount, dragCount)
        XCTAssertTrue(Set(NSApp.windows.map(ObjectIdentifier.init)).subtracting(windows).isEmpty)
        XCTAssertFalse(state.isBusy); XCTAssertTrue(state.lastOutputs.isEmpty)
    }

    @MainActor func testEventsInsideTutorialCancelExternalWheelWithoutConverting() throws {
        _ = NSApplication.shared
        let state = try makeState()
        let overlay = OverlayPanelController(state: state)
        overlay.showForFiles([SampleResources.imageURL], mode: .conversion, at: .init(x: 400, y: 400))
        XCTAssertNotNil(overlay.model)
        var performed = false
        overlay.onDrop = { _, _ in performed = true }
        let monitor = GlobalDragMonitor(overlay: overlay, state: state, suppressesEvent: { true })
        monitor.handle(try event(.leftMouseDragged, at: .init(x: 420, y: 205), modifiers: .shift))
        XCTAssertNil(overlay.model)
        monitor.handle(try event(.leftMouseUp, at: .init(x: 420, y: 205), modifiers: .shift))
        XCTAssertFalse(performed); XCTAssertTrue(state.lastOutputs.isEmpty)
    }

    @MainActor private func makeState() throws -> AppState {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "OrbitMorphIsolation-\(UUID().uuidString)"))
        return AppState(store: .init(defaults: defaults), dependencies: .init(overrides: ["magick": nil, "ffmpeg": nil, "ffprobe": nil, "soffice": nil, "ebook-convert": nil, "7zz": nil]))
    }

    @MainActor private func event(_ type: NSEvent.EventType, at point: NSPoint, modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
    }
}
