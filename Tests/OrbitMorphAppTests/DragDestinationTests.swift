import AppKit
import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class DragDestinationTests: XCTestCase {
    @MainActor func testGlassWheelBlursBehindWindowEvenWhenInactive() throws {
        _ = NSApplication.shared
        let model = WheelViewModel(items: [.init(value: .format(.jpg))], mode: .conversion, appearance: .glass)
        let view = DragReceivingView(model: model, frame: NSRect(x: 0, y: 0, width: 310, height: 310), resolveItems: { _ in [] })
        let glass = try XCTUnwrap(view.subviews.compactMap { $0 as? NSVisualEffectView }.first)
        XCTAssertEqual(glass.blendingMode, .behindWindow)
        XCTAssertEqual(glass.state, .active)
        XCTAssertEqual(glass.material, .hudWindow)
        XCTAssertEqual(glass.frame, NSRect(x: 16, y: 16, width: 278, height: 278))
        XCTAssertEqual(glass.alphaValue, 0.78, accuracy: 0.001)
    }

    @MainActor func testSolidWheelDoesNotInstallBackdropBlur() {
        _ = NSApplication.shared
        let model = WheelViewModel(items: [.init(value: .format(.jpg))], mode: .conversion, appearance: .solid)
        let view = DragReceivingView(model: model, frame: NSRect(x: 0, y: 0, width: 310, height: 310), resolveItems: { _ in [] })
        XCTAssertFalse(view.subviews.contains { $0 is NSVisualEffectView })
    }

    @MainActor func testDropDestinationResolvesFilesSelectsSegmentAndConverts() throws {
        _ = NSApplication.shared
        let resolver = DependencyResolver()
        guard let magick = resolver.path(for: "magick") else { throw XCTSkip("ImageMagick is not installed") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorph-drag-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("拖拽 fixture.png")
        try ProcessRunner.run(.init(executable: magick, arguments: ["-size", "24x12", "xc:orange", file.path]))
        let model = WheelViewModel(items: [], mode: .conversion)
        let view = DragReceivingView(model: model, frame: NSRect(x: 0, y: 0, width: 310, height: 310), resolveItems: { _ in [.init(value: .format(.jpg))] })
        var resolved: [URL] = [], result: [ConversionResult] = []
        var dropError: Error?
        view.onFilesResolved = { resolved = $0 }
        view.onDrop = { item, files in
            do {
                guard case .format(let format) = item.value else { return }
                result = try ConversionEngine(dependencies: resolver).convert(.init(inputs: files, target: format))
            } catch { dropError = error }
        }
        let sender = DragFixture(files: [file], location: NSPoint(x: 155, y: 255))
        XCTAssertEqual(view.draggingEntered(sender), .copy)
        XCTAssertEqual(resolved, [file])
        XCTAssertEqual(view.draggingUpdated(sender), .copy)
        XCTAssertEqual(model.selected?.value, .format(.jpg))
        XCTAssertTrue(view.performDragOperation(sender))
        XCTAssertNil(dropError)
        let output = try XCTUnwrap(result.first?.outputURL)
        XCTAssertEqual(try ProcessRunner.run(.init(executable: magick, arguments: ["identify", "-format", "%m", output.path])).output, "JPEG")
    }

    @MainActor func testWheelPagingKeepsAdditionalTargetsSelectable() {
        let values: [FormatID] = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf]
        let model = WheelViewModel(items: values.map { .init(value: .format($0)) }, mode: .conversion)
        XCTAssertEqual(model.visibleItems.count, 8)
        model.nextPage(); model.selectedIndex = 0
        XCTAssertEqual(model.selected?.value, .format(.pdf))
        model.nextPage()
        XCTAssertNil(model.selectedIndex)
        XCTAssertEqual(model.visibleItems.first?.value, .format(.jpg))
    }

    @MainActor func testDropInCenterDoesNotExecuteConversion() {
        _ = NSApplication.shared
        let model = WheelViewModel(items: [.init(value: .format(.jpg))], mode: .conversion)
        let view = DragReceivingView(model: model, frame: NSRect(x: 0, y: 0, width: 310, height: 310), resolveItems: { _ in model.items })
        let sender = DragFixture(files: [], location: NSPoint(x: 155, y: 155))
        var performed = false
        view.onDrop = { _, _ in performed = true }
        XCTAssertEqual(view.draggingUpdated(sender), [])
        XCTAssertFalse(view.performDragOperation(sender))
        XCTAssertFalse(performed)
    }

    @MainActor func testDraggingAcrossDifferentWheelSegmentsEmitsFeedbackTicks() {
        _ = NSApplication.shared
        var now = 1.0
        var plays = 0
        let feedback = WheelFeedbackController(minimumInterval: 0.01, now: { now }, play: { plays += 1 })
        let items = [WheelDisplayItem(value: .format(.jpg)), WheelDisplayItem(value: .format(.png))]
        let model = WheelViewModel(items: items, mode: .conversion)
        let view = DragReceivingView(
            model: model,
            frame: NSRect(x: 0, y: 0, width: 310, height: 310),
            resolveItems: { _ in items },
            feedback: feedback,
            feedbackEnabled: { true }
        )
        let sender = DragFixture(files: [], location: NSPoint(x: 155, y: 255))
        _ = view.draggingUpdated(sender)
        now += 0.02
        sender.draggingLocation = NSPoint(x: 155, y: 55)
        _ = view.draggingUpdated(sender)
        XCTAssertEqual(plays, 2)
    }

    @MainActor func testExplicitPageSelectionClearsPreviousSegmentAndLimitsPageToEightItems() {
        let values: [FormatID] = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf, .svg, .doc, .docx, .txt, .md, .rtf, .html, .odt]
        let model = WheelViewModel(items: values.map { .init(value: .format($0)) }, mode: .conversion)
        model.selectedIndex = 3
        model.page = 1
        XCTAssertNil(model.selectedIndex)
        XCTAssertEqual(model.visibleItems.count, 8)
        XCTAssertEqual(model.visibleItems.first?.value, .format(.pdf))
        model.page = 2
        XCTAssertEqual(model.visibleItems.map(\.value), [.format(.odt)])
    }

    @MainActor func testStationaryDragOverPageNumberSwitchesOnceAndCanDropOnSecondPage() async throws {
        let (view, model, sender, file) = try pagedDragFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        var selected: WheelDisplayItem.Value?
        view.onDrop = { item, _ in selected = item.value }
        _ = view.draggingEntered(sender)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(model.page, 0)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(model.page, 1)
        XCTAssertNil(model.selectedIndex)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(model.page, 1)
        sender.draggingLocation = NSPoint(x: 155, y: 255)
        XCTAssertTrue(view.performDragOperation(sender))
        XCTAssertEqual(selected, .format(.pdf))
    }

    @MainActor func testLeavingPageNumberBeforeDwellCancelsPendingSwitch() async throws {
        let (view, model, sender, file) = try pagedDragFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        _ = view.draggingEntered(sender)
        try await Task.sleep(for: .milliseconds(100))
        sender.draggingLocation = NSPoint(x: 155, y: 255)
        _ = view.draggingUpdated(sender)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(model.page, 0)
        XCTAssertEqual(model.selected?.value, .format(.jpg))
    }

    @MainActor func testExitAndReentryRequireFreshPageDwell() async throws {
        let (view, model, sender, file) = try pagedDragFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        _ = view.draggingEntered(sender)
        try await Task.sleep(for: .milliseconds(100))
        view.draggingExited(sender)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(model.page, 0)
        _ = view.draggingEntered(sender)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(model.page, 0)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(model.page, 1)
    }

    @MainActor func testCenterReleaseNeverDropsAndCancelsPageDwell() async throws {
        let (view, model, sender, file) = try pagedDragFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        var dropCount = 0
        view.onDrop = { _, _ in dropCount += 1 }
        _ = view.draggingEntered(sender)
        XCTAssertFalse(view.performDragOperation(sender))
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(dropCount, 0)
        XCTAssertEqual(model.page, 0)
    }

    @MainActor func testOverlayCancellationCancelsPendingPageSwitch() async throws {
        let (view, model, sender, file) = try pagedDragFixture()
        defer { try? FileManager.default.removeItem(at: file) }
        _ = view.draggingEntered(sender)
        view.animateOut()
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(model.page, 0)
    }

    @MainActor func testThreePageBandsSelectTopMiddleAndBottomDirectly() async throws {
        let values: [FormatID] = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf, .svg, .doc, .docx, .txt, .md, .rtf, .html, .odt]
        let (view, model, sender, file) = try pagedDragFixture(values: values)
        defer { try? FileManager.default.removeItem(at: file) }
        _ = view.draggingEntered(sender)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(model.page, 2)
        XCTAssertEqual(model.visibleItems.first?.value, .format(.odt))
        sender.draggingLocation = NSPoint(x: 155, y: 155)
        _ = view.draggingUpdated(sender)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(model.page, 1)
        sender.draggingLocation = NSPoint(x: 155, y: 185)
        _ = view.draggingUpdated(sender)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(model.page, 0)
    }

    @MainActor private func pagedDragFixture(values: [FormatID] = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf]) throws -> (DragReceivingView, WheelViewModel, DragFixture, URL) {
        _ = NSApplication.shared
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("page-drag-\(UUID().uuidString).png")
        try Data("fixture".utf8).write(to: file)
        let items = values.map { WheelDisplayItem(value: .format($0)) }
        let model = WheelViewModel(items: items, mode: .conversion)
        let view = DragReceivingView(model: model, frame: NSRect(x: 0, y: 0, width: 310, height: 310), resolveItems: { _ in items }, feedbackEnabled: { false })
        return (view, model, DragFixture(files: [file], location: NSPoint(x: 155, y: 130)), file)
    }

    @MainActor func testWindowControllersCanCloseAndReopen() {
        _ = NSApplication.shared
        let suite = "OrbitMorphUI-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(store: .init(defaults: defaults))
        let drop = DropWindowController(state: state) { _ in }
        let settings = SettingsWindowController(state: state)
        drop.show(); drop.window.close(); drop.show()
        XCTAssertTrue(drop.window.isVisible)
        settings.show(); settings.window.close(); settings.show()
        XCTAssertTrue(settings.window.isVisible)
        drop.window.orderOut(nil); settings.window.orderOut(nil)
    }
}

@MainActor
private final class DragFixture: NSObject, @preconcurrency NSDraggingInfo {
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint
    var draggedImageLocation: NSPoint { draggingLocation }
    var draggedImage: NSImage? { nil }
    let draggingPasteboard: NSPasteboard
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 0
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    init(files: [URL], location: NSPoint) {
        draggingLocation = location
        draggingPasteboard = NSPasteboard.withUniqueName()
        super.init()
        draggingPasteboard.writeObjects(files.map { $0 as NSURL })
    }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions, for view: NSView?, classes: [AnyClass],
                               searchOptions: [NSPasteboard.ReadingOptionKey: Any], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}
