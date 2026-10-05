import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class SampleResourceSafetyTests: XCTestCase {
    func testTutorialSamplesAreWritableCopiesAndNeverWriteIntoSourceBundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphSampleTest-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent("ReadOnly.app/Contents/Resources/Samples")
        let workspace = root.appendingPathComponent("workspace")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try TextSampleFixture.make(in: bundle)
        let original = try Data(contentsOf: source)
        let staged = try SampleResources.prepareSample(source: source, in: workspace)
        XCTAssertEqual(staged.deletingLastPathComponent().standardizedFileURL.path, workspace.standardizedFileURL.path)
        XCTAssertEqual(try Data(contentsOf: staged), original)
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [staged], target: .jpg)).first?.outputURL)
        XCTAssertEqual(output.deletingLastPathComponent().standardizedFileURL.path, workspace.standardizedFileURL.path)
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bundle.path), [source.lastPathComponent])
    }

    func testMissingSourceIsReportedInsteadOfCreatingBrokenSample() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphSampleTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try SampleResources.prepareSample(source: root.appendingPathComponent("missing.png"), in: root.appendingPathComponent("workspace")))
    }
}

private enum TextSampleFixture {
    static func make(in root: URL) throws -> URL {
        let url = root.appendingPathComponent("sample.png")
        try ProcessRunner.run(.init(executable: "/opt/homebrew/bin/magick", arguments: ["-size", "16x16", "xc:orange", url.path]))
        return url
    }
}
