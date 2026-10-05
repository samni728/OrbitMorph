import XCTest
@testable import OrbitMorphCore

final class OutputValidationTests: XCTestCase {
    func testFFmpegOnlyValidationRequiresTheExpectedStream() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StreamValidation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("audio.m4a"), video = root.appendingPathComponent("silent.mp4")
        try ProcessRunner.run(.init(executable: "/opt/homebrew/bin/ffmpeg", arguments: ["-v", "error", "-f", "lavfi", "-i", "sine=frequency=600:duration=0.4", audio.path]))
        try ProcessRunner.run(.init(executable: "/opt/homebrew/bin/ffmpeg", arguments: ["-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=32x32:d=0.4", "-c:v", "libx264", "-an", video.path]))
        let dependencies = DependencyResolver(overrides: ["ffprobe": nil])
        XCTAssertNoThrow(try OutputValidation.validate(audio, target: .m4a, dependencies: dependencies))
        XCTAssertNoThrow(try OutputValidation.validate(video, target: .mp4, dependencies: dependencies))
        XCTAssertThrowsError(try OutputValidation.validate(audio, target: .mp4, dependencies: dependencies))
        XCTAssertThrowsError(try OutputValidation.validate(video, target: .mp3, dependencies: dependencies))
    }
    func testNonemptyGarbageCannotPassImageOrMediaValidation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("InvalidOutputs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for target in [FormatID.png, .gif, .mp4, .mp3] {
            let output = root.appendingPathComponent("garbage.\(target.fileExtension)")
            try Data("successful CLI, invalid result".utf8).write(to: output)
            XCTAssertThrowsError(try OutputValidation.validate(output, target: target), target.rawValue)
        }
    }
    func testExitZeroCannotPublishEmptyOutputOrCorruptDOCX() throws {
        for body in [": > \"$out\"", "printf 'garbage' > \"$out\""] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphValidate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let executable = root.appendingPathComponent("textutil")
            let script = "#!/bin/sh\nwhile [ $# -gt 0 ]; do\nif [ \"$1\" = -output ]; then shift; out=$1; fi\nshift\ndone\n\(body)\n"
            try script.write(to: executable, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
            let input = root.appendingPathComponent("source.txt")
            try "OrbitMorph text".write(to: input, atomically: true, encoding: .utf8)
            let engine = ConversionEngine(dependencies: .init(overrides: ["textutil": executable.path, "pandoc": nil]))
            XCTAssertThrowsError(try engine.convert(.init(inputs: [input], target: .docx)))
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("source.docx").path))
            XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)), Set(["textutil", "source.txt"]))
        }
    }
}
