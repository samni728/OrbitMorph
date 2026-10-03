import XCTest
@testable import OrbitMorphCore

final class ConversionIntegrationTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorph-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func run(_ executable: String, _ arguments: [String]) throws -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        try p.run(); p.waitUntilExit()
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(p.terminationStatus, 0, "Command failed: \(executable) \(arguments)\n\(text)")
        return text
    }

    func testImageConversionHandlesUnicodeAndSpaces() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("测试 source image.png")
        try run("/opt/homebrew/bin/magick", ["-size", "40x30", "xc:#ff6a3d", source.path])
        let engine = ConversionEngine(dependencies: DependencyResolver())
        let result = try engine.convert(ConversionJob(inputs: [source], target: .webp, outputDirectory: root))
        let output = try XCTUnwrap(result.first?.outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0, 0)
        let identify = try run("/opt/homebrew/bin/magick", ["identify", "-format", "%m", output.path])
        XCTAssertEqual(identify, "WEBP")
    }

    func testVideoMovToMp4AndExtractMp3() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("fixture.mov")
        try run("/opt/homebrew/bin/ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=blue:s=160x120:d=0.6", "-f", "lavfi", "-i", "sine=frequency=880:duration=0.6", "-c:v", "libx264", "-c:a", "aac", "-shortest", source.path])
        let engine = ConversionEngine(dependencies: DependencyResolver())
        let mp4 = try XCTUnwrap(try engine.convert(.init(inputs: [source], target: .mp4, outputDirectory: root)).first?.outputURL)
        let mp3 = try XCTUnwrap(try engine.convert(.init(inputs: [source], target: .mp3, outputDirectory: root)).first?.outputURL)
        let mp4Probe = try run("/opt/homebrew/bin/ffprobe", ["-v", "error", "-show_entries", "format=format_name", "-of", "default=nw=1:nk=1", mp4.path])
        XCTAssertTrue(mp4Probe.contains("mp4"))
        let mp3Probe = try run("/opt/homebrew/bin/ffprobe", ["-v", "error", "-show_entries", "format=format_name", "-of", "default=nw=1:nk=1", mp3.path])
        XCTAssertTrue(mp3Probe.contains("mp3"))
    }

    func testDocumentTxtToDocx() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("notes.txt")
        try "OrbitMorph document conversion\n".write(to: source, atomically: true, encoding: .utf8)
        let engine = ConversionEngine(dependencies: DependencyResolver())
        let output = try XCTUnwrap(try engine.convert(.init(inputs: [source], target: .docx, outputDirectory: root)).first?.outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0, 100)
    }

    func testZipToSevenZip() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let payload = root.appendingPathComponent("payload.txt")
        try "archive payload".write(to: payload, atomically: true, encoding: .utf8)
        let zip = root.appendingPathComponent("fixture.zip")
        try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", payload.path, zip.path])
        let engine = ConversionEngine(dependencies: DependencyResolver())
        let output = try XCTUnwrap(try engine.convert(.init(inputs: [zip], target: .sevenZ, outputDirectory: root)).first?.outputURL)
        let listing = try run("/opt/homebrew/bin/7zz", ["l", output.path])
        XCTAssertTrue(listing.contains("payload.txt"))
    }

    func testProcessInvocationKeepsUserPathsAsSingleArguments() {
        let input = URL(fileURLWithPath: "/tmp/a 'quoted' 文件.mov")
        let output = URL(fileURLWithPath: "/tmp/out file.mp4")
        let invocation = FFmpegAdapter.invocation(input: input, output: output, target: .mp4, ffmpegPath: "/opt/homebrew/bin/ffmpeg")
        XCTAssertEqual(invocation.executable, "/opt/homebrew/bin/ffmpeg")
        XCTAssertTrue(invocation.arguments.contains(input.path))
        XCTAssertTrue(invocation.arguments.contains(output.path))
        XCTAssertFalse(invocation.arguments.joined(separator: " ").contains("sh -c"))
    }
}
