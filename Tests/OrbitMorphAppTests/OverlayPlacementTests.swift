import AppKit
import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class OverlayPlacementTests: XCTestCase {
    @MainActor func testDemoUsesRealPNGTargetsInsteadOfCrossCategoryFormats() throws {
        _ = NSApplication.shared
        let suite = "OrbitMorphOverlay-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(store: .init(defaults: defaults))
        let controller = OverlayPanelController(state: state)
        defer { controller.hide() }
        controller.showDemo()
        let items = try XCTUnwrap(controller.model).items
        XCTAssertEqual(items, controller.items(for: [SampleResources.imageURL], mode: .conversion))
        XCTAssertFalse(items.contains { $0.value == .format(.mp4) || $0.value == .format(.mp3) })
    }

    @MainActor func testDemoSecondPageShowsRemainingTargetsAndClampsRequestedPage() throws {
        _ = NSApplication.shared
        let suite = "OrbitMorphDemoPage-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = OverlayPanelController(state: AppState(store: .init(defaults: defaults)))
        defer { controller.hide() }
        controller.showDemo(pageNumber: 2)
        let model = try XCTUnwrap(controller.model)
        guard model.pageCount > 1 else { throw XCTSkip("Second-page demo needs installed image converters") }
        XCTAssertEqual(model.page, 1)
        XCTAssertFalse(model.visibleItems.contains { $0.value == .format(.jpg) || $0.value == .format(.mp4) })
        XCTAssertTrue(model.visibleItems.contains { $0.value == .format(.docx) })
        controller.showDemo(pageNumber: Int.min)
        XCTAssertEqual(controller.model?.page, 0)
        controller.showDemo(pageNumber: Int.max)
        XCTAssertEqual(controller.model?.page, (controller.model?.pageCount ?? 1) - 1)
    }

    @MainActor func testPanelUsesScreenContainingExplicitPointerAndClampsAtItsEdge() throws {
        _ = NSApplication.shared
        let suite = "OrbitMorphPlacement-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(store: .init(defaults: defaults), dependencies: .init(overrides: ["ffmpeg": nil, "magick": nil, "soffice": nil, "ebook-convert": nil, "7zz": nil]))
        let controller = OverlayPanelController(state: state)
        defer { controller.hide() }
        for screen in NSScreen.screens {
            let point = NSPoint(x: screen.frame.minX + 1, y: screen.frame.minY + 1)
            let previous = Set(NSApp.windows.map(ObjectIdentifier.init))
            controller.show(items: [.init(value: .format(.jpg))], mode: .conversion, at: point)
            let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? NSPanel }.first { !previous.contains(ObjectIdentifier($0)) && $0.isVisible && $0.level == .popUpMenu })
            XCTAssertEqual(window.frame.minX, screen.visibleFrame.minX, accuracy: 0.1)
            XCTAssertEqual(window.frame.minY, screen.visibleFrame.minY, accuracy: 0.1)
            controller.hide()
        }
    }
}
