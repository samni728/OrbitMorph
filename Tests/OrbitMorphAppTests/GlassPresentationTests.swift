import AppKit
import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class GlassPresentationTests: XCTestCase {
    func testMaterialPolicyHonorsSolidAndAccessibilityFallbacks() {
        XCTAssertTrue(GlassPolicy.usesMaterial(appearance: .glass, reduceTransparency: false, increaseContrast: false))
        XCTAssertFalse(GlassPolicy.usesMaterial(appearance: .solid, reduceTransparency: false, increaseContrast: false))
        XCTAssertFalse(GlassPolicy.usesMaterial(appearance: .glass, reduceTransparency: true, increaseContrast: false))
        XCTAssertFalse(GlassPolicy.usesMaterial(appearance: .glass, reduceTransparency: false, increaseContrast: true))
    }

    @MainActor func testSnapshotCompositesTransparentCacheOntoOpaqueMatte() throws {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<2 { for y in 0..<2 { rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0), atX: x, y: y) } }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("glass-snapshot-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: output) }
        try WindowSnapshot.write(rep, to: output, appearance: try XCTUnwrap(NSAppearance(named: .aqua)))
        let result = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: output)))
        let color = try XCTUnwrap(result.colorAt(x: 0, y: 0))
        XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.01)
        XCTAssertGreaterThan(color.usingColorSpace(.deviceRGB)!.redComponent, 0.8)
    }

    @MainActor func testSamplePreviewCannotPaintOutsideItsBoundsDuringCacheDisplay() throws {
        _ = NSApplication.shared
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Samples/OrbitMorph-Sample.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        let sample = SampleDragSourceView(fileURL: source)
        sample.frame = NSRect(x: 79, y: 46, width: 142, height: 108)
        parent.addSubview(sample)
        let rep = try XCTUnwrap(parent.bitmapImageRepForCachingDisplay(in: parent.bounds))
        parent.cacheDisplay(in: parent.bounds, to: rep)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("sample-preview-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: output) }
        try WindowSnapshot.write(rep, to: output, appearance: try XCTUnwrap(NSAppearance(named: .aqua)))
        let result = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: output)))
        for point in [(10, 10), (290, 190)] {
            let color = try XCTUnwrap(result.colorAt(x: point.0, y: point.1)?.usingColorSpace(.deviceRGB))
            XCTAssertGreaterThan(color.redComponent, 0.8)
            XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.01)
        }
    }

    @MainActor func testSettingsAndTutorialInstallBehindWindowMaterialAndRefreshLanguage() throws {
        _ = NSApplication.shared
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "OrbitMorphGlass-\(UUID().uuidString)"))
        let state = AppState(store: .init(defaults: defaults), dependencies: .init(overrides: ["ffmpeg": nil, "magick": nil, "soffice": nil, "ebook-convert": nil, "7zz": nil]))
        let settings = SettingsWindowController(state: state)
        let manager = OnboardingManager(state: state, imageSampleURL: URL(fileURLWithPath: "/tmp/test.png"), videoSampleURL: URL(fileURLWithPath: "/tmp/test.mp4"))
        let tutorial = TutorialWindowController(manager: manager, onOpenFolders: {})
        for window in [settings.window, tutorial.window] {
            XCTAssertTrue(window.contentView is NSVisualEffectView)
            XCTAssertEqual((window.contentView as? NSVisualEffectView)?.blendingMode, .behindWindow)
            XCTAssertFalse(window.isOpaque)
        }
        state.settings.language = .zhHans
        XCTAssertEqual(settings.window.title, "OrbitMorph 设置")
        XCTAssertEqual(tutorial.window.title, "OrbitMorph 使用教程")
        state.settings.appearance = .solid
        for window in [settings.window, tutorial.window] {
            XCTAssertTrue(window.isOpaque)
            XCTAssertEqual((window.contentView as? NSVisualEffectView)?.blendingMode, .withinWindow)
        }
    }
}
