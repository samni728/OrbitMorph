import Foundation
import XCTest
@testable import OrbitMorphCore

final class MediaCapabilityTests: XCTestCase {
    func testExtendedVideoQualityReachesEncoder() throws {
        for format in [FormatID.ts, .threeGP, .flv] {
            let key = format == .flv ? "-q:v" : "-crf"
            func arguments(_ quality: Double) -> [String] {
                FFmpegAdapter.invocation(input: URL(fileURLWithPath: "/tmp/in.mp4"),
                    output: URL(fileURLWithPath: "/tmp/out.\(format.fileExtension)"), target: format,
                    ffmpegPath: "/opt/homebrew/bin/ffmpeg", options: .init(quality: quality)).arguments
            }
            let low = arguments(0.2), high = arguments(0.9)
            let lowIndex = try XCTUnwrap(low.firstIndex(of: key), format.rawValue)
            let highIndex = try XCTUnwrap(high.firstIndex(of: key), format.rawValue)
            XCTAssertLessThan(try XCTUnwrap(Int(high[highIndex + 1])), try XCTUnwrap(Int(low[lowIndex + 1])))
        }
    }

    func testSuccessfulProbeWithPlainTextOutputDoesNotAdvertiseFormats() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MediaProbe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = root.appendingPathComponent("ffmpeg")
        try "#!/bin/sh\nfor arg in \"$@\"; do last=\"$arg\"; done\nprintf 'not a media file' > \"$last\"\nexit 0\n".write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        for format in [FormatID.flv, .ts, .threeGP, .caf] {
            XCTAssertFalse(FFmpegAdapter.canEncodeExtended(format, ffmpegPath: fake.path), format.rawValue)
        }
        XCTAssertFalse(FFmpegAdapter.canEncodeWMV(ffmpegPath: fake.path))
        XCTAssertFalse(FFmpegAdapter.canEncodeWMA(ffmpegPath: fake.path))
    }
}
