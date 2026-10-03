import XCTest
@testable import OrbitMorphCore

final class CoreRegistryTests: XCTestCase {
    func testFormatNormalizationAndClassification() {
        XCTAssertEqual(FormatID(extension: "JPEG"), .jpg)
        XCTAssertEqual(FormatID(extension: ".heif"), .heic)
        XCTAssertEqual(FormatID(extension: "mkv")?.kind, .video)
        XCTAssertEqual(FormatID(extension: "docx")?.kind, .document)
        XCTAssertEqual(FormatID(extension: "7z")?.kind, .archive)
        XCTAssertNil(FormatID(extension: "wat"))
    }

    func testRegistryFiltersRoutesWhenDependencyMissing() {
        let deps = DependencyResolver(overrides: ["ffmpeg": nil, "magick": "/opt/homebrew/bin/magick"])
        let registry = ConversionRegistry(dependencies: deps)
        XCTAssertFalse(registry.targets(for: .mov).contains(.mp4))
        XCTAssertTrue(registry.targets(for: .png).contains(.jpg))
    }

    func testMultiFileTargetsAreIntersection() {
        let deps = DependencyResolver(overrides: ["ffmpeg": "/opt/homebrew/bin/ffmpeg", "magick": "/opt/homebrew/bin/magick"])
        let registry = ConversionRegistry(dependencies: deps)
        let targets = registry.commonTargets(for: [.png, .jpg])
        XCTAssertTrue(targets.contains(.webp))
        XCTAssertFalse(targets.contains(.mp4))
    }

    func testOutputNamerNeverOverwritesExistingFile() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("hello world.png")
        try Data().write(to: source)
        let first = root.appendingPathComponent("hello world.jpg")
        try Data().write(to: first)
        let second = root.appendingPathComponent("hello world-converted.jpg")
        try Data().write(to: second)

        let output = OutputNamer.outputURL(for: source, target: .jpg, in: root, fileManager: fm)
        XCTAssertEqual(output.lastPathComponent, "hello world-converted-2.jpg")
    }
}
