import Foundation
import XCTest
@testable import OrbitMorphCore

final class FormatExpansionTests: XCTestCase {
    func testNewFormatsHaveExpectedCategoriesAndSVGIsInputOnly() {
        XCTAssertEqual(FormatID(extension: "SVG"), .svg)
        XCTAssertEqual(FormatID(extension: "wmv"), .wmv)
        XCTAssertEqual(FormatID(extension: "wma"), .wma)
        XCTAssertEqual(FormatID(extension: "srt")?.kind, .subtitle)
        XCTAssertEqual(FormatID(extension: "vtt")?.kind, .subtitle)
        let registry = ConversionRegistry()
        XCTAssertEqual(registry.targets(for: .svg), [.png, .jpg, .webp, .pdf])
        XCTAssertFalse(FormatID.allCases.contains { registry.targets(for: $0).contains(.svg) })
        XCTAssertEqual(registry.targets(for: .srt), [.vtt])
        XCTAssertEqual(registry.targets(for: .vtt), [.srt])
        XCTAssertEqual(ToolRegistry.actions(for: .svg), [.archive])
        XCTAssertEqual(ToolRegistry.actions(for: .srt), [.archive])
    }

    func testSVGReadProbeHidesRoutesWhenDelegateFails() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = root.appendingPathComponent("magick")
        try "#!/bin/sh\nif [ \"$1\" = \"-list\" ]; then\n  echo ' SVG SVG rw+ Scalable Vector Graphics'\n  exit 0\nfi\nexit 1\n"
            .write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let registry = ConversionRegistry(dependencies: DependencyResolver(overrides: ["magick": fake.path]))
        XCTAssertTrue(registry.targets(for: .svg).isEmpty)
    }

    func testWMVAndWMATargetsRequireWorkingEncodersAndMuxers() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = root.appendingPathComponent("ffmpeg")
        try "#!/bin/sh\nif [ \"$2\" = \"-encoders\" ]; then\n  echo ' A..... wmav2 Windows Media Audio 2'\n  exit 0\nfi\nexit 1\n".write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let registry = ConversionRegistry(dependencies: DependencyResolver(overrides: ["ffmpeg": fake.path]))
        XCTAssertFalse(registry.targets(for: .mp4).contains(.wmv))
        XCTAssertFalse(registry.targets(for: .mp3).contains(.wma))
        let available = ConversionRegistry()
        XCTAssertTrue(available.targets(for: .mp4).contains(.wmv))
        XCTAssertTrue(available.targets(for: .mp3).contains(.wma))
    }

    func testSubtitleRoundTripPreservesIdentifiersUnicodeAndMultiline() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input.srt")
        try "\u{FEFF}1\r\n00:00:01,234 --> 00:00:03,456\r\n你好 🌍\r\nsecond line\r\n\r\n2\r\n01:02:03,004 --> 01:02:04,000\r\nlast\r\n".write(to: input, atomically: true, encoding: .utf8)
        let engine = ConversionEngine()
        let vtt = try XCTUnwrap(engine.convert(.init(inputs: [input], target: .vtt)).first?.outputURL)
        let webVTT = try String(contentsOf: vtt, encoding: .utf8)
        XCTAssertTrue(webVTT.hasPrefix("WEBVTT\n\n"))
        XCTAssertTrue(webVTT.contains("1\n00:00:01.234 --> 00:00:03.456\n你好 🌍\nsecond line"))
        let srt = try XCTUnwrap(engine.convert(.init(inputs: [vtt], target: .srt)).first?.outputURL)
        let result = try String(contentsOf: srt, encoding: .utf8)
        XCTAssertTrue(result.contains("1\n00:00:01,234 --> 00:00:03,456\n你好 🌍\nsecond line"))
        XCTAssertTrue(result.contains("2\n01:02:03,004 --> 01:02:04,000\nlast"))
    }

    func testVTTNoteAndOmittedHoursDoNotBecomeSubtitles() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input.vtt")
        try "\u{FEFF}WEBVTT\r\n\r\nNOTE internal note\r\nnot a caption\r\n\r\ncue-1\r\n00:01.250 --> 00:02.500\r\n字幕\r\nnext line\r\n".write(to: input, atomically: true, encoding: .utf8)
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .srt)).first?.outputURL)
        let text = try String(contentsOf: output, encoding: .utf8)
        XCTAssertFalse(text.contains("internal note"))
        XCTAssertFalse(text.contains("not a caption"))
        XCTAssertTrue(text.contains("1\n00:00:01,250 --> 00:00:02,500\n字幕\nnext line"))
        XCTAssertFalse(text.contains("cue-1"))
    }

    func testVTTNamedCuesBecomeNumericSRTSequenceAndFlexibleTimingWhitespace() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("named.vtt")
        try "WEBVTT\n\nintro\n00:01.000  -->\t00:02.000\nfirst\n\nending\n00:03.000\t-->  00:04.000\nlast\n"
            .write(to: input, atomically: true, encoding: .utf8)
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .srt)).first?.outputURL)
        let text = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(text.contains("1\n00:00:01,000 --> 00:00:02,000\nfirst"))
        XCTAssertTrue(text.contains("2\n00:00:03,000 --> 00:00:04,000\nlast"))
        XCTAssertFalse(text.contains("intro"))
        XCTAssertFalse(text.contains("ending"))
    }

    func testSRTRejectsNonnumericCueIdentifiers() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("named.srt")
        try "intro\n00:00:01,000 --> 00:00:02,000\ntext\n".write(to: input, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ConversionEngine().convert(.init(inputs: [input], target: .vtt)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("named.vtt").path))
    }

    func testCueTimingArrowInPayloadCannotBeSilentlyRenderedAsText() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let malformedVTT = root.appendingPathComponent("merged.vtt")
        try "WEBVTT\n\n00:01.000 --> 00:02.000\nfirst\n00:03.000 --> 00:04.000\nsecond\n"
            .write(to: malformedVTT, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ConversionEngine().convert(.init(inputs: [malformedVTT], target: .srt)))
        let literalSRT = root.appendingPathComponent("literal.srt")
        try "1\n00:00:01,000 --> 00:00:02,000\nA --> B\n"
            .write(to: literalSRT, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ConversionEngine().convert(.init(inputs: [literalSRT], target: .vtt)))
    }

    func testWMVQualityOptionReachesEncoder() {
        let input = URL(fileURLWithPath: "/tmp/input.mp4")
        let output = URL(fileURLWithPath: "/tmp/output.wmv")
        let low = FFmpegAdapter.invocation(input: input, output: output, target: .wmv,
                                           ffmpegPath: "/opt/homebrew/bin/ffmpeg", options: .init(quality: 0.2)).arguments
        let high = FFmpegAdapter.invocation(input: input, output: output, target: .wmv,
                                            ffmpegPath: "/opt/homebrew/bin/ffmpeg", options: .init(quality: 0.9)).arguments
        guard let lowIndex = low.firstIndex(of: "-q:v"), let highIndex = high.firstIndex(of: "-q:v") else {
            return XCTFail("WMV quality option not passed to encoder")
        }
        XCTAssertLessThan(Int(high[highIndex + 1])!, Int(low[lowIndex + 1])!)
    }

    func testWindowsMediaCompressToolNeedsWorkingEncoder() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = root.appendingPathComponent("ffmpeg")
        try "#!/bin/sh\nexit 1\n".write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let unavailable = DependencyResolver(overrides: ["ffmpeg": fake.path])
        for format in [FormatID.wmv, .wma] {
            let actions = ToolRegistry.commonActions(for: [format], dependencies: unavailable)
            XCTAssertFalse(actions.contains(.compress), "\(format) advertised an unavailable encoder")
            XCTAssertTrue(actions.contains(.archive))
            XCTAssertTrue(actions.contains(.stripMetadata))
            XCTAssertTrue(ToolRegistry.commonActions(for: [format]).contains(.compress))
        }
    }

    func testUnsupportedVTTBlocksAndInvalidCuesFailWithoutOutput() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        for (name, body) in [
            ("style", "WEBVTT\n\nSTYLE\n::cue { color: red }\n"),
            ("bad-time", "WEBVTT\n\n00:99.000 --> 00:02.000\ntext\n"),
            ("bad-arrow", "WEBVTT\n\n00:01.000 -> 00:02.000\ntext\n"),
            ("cue-settings", "WEBVTT\n\n00:01.000 --> 00:02.000 align:start\ntext\n")
        ] {
            let input = root.appendingPathComponent("\(name).vtt")
            try body.write(to: input, atomically: true, encoding: .utf8)
            XCTAssertThrowsError(try ConversionEngine().convert(.init(inputs: [input], target: .srt)), name)
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("\(name).srt").path))
        }
    }

    func testExtraBlankLinesAreSeparatorsAndHugeTimestampsFailCleanly() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("spaced.vtt")
        try "WEBVTT\n\n\n00:01.000 --> 00:02.000\nfirst\n\n\n00:03.000 --> 00:04.000\nsecond\n"
            .write(to: input, atomically: true, encoding: .utf8)
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .srt)).first?.outputURL)
        let result = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(result.contains("first\n\n2\n00:00:03,000"))
        let huge = root.appendingPathComponent("huge.vtt")
        try "WEBVTT\n\n99999999999999999:00:00.000 --> 99999999999999999:00:01.000\ntext\n"
            .write(to: huge, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ConversionEngine().convert(.init(inputs: [huge], target: .srt)))
    }

    func testSubtitleCollisionAndBatchFailureKeepExistingOutput() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let valid = root.appendingPathComponent("valid.srt")
        let bad = root.appendingPathComponent("bad.srt")
        let existing = root.appendingPathComponent("valid.vtt")
        try "1\n00:00:00,000 --> 00:00:01,000\nhello\n".write(to: valid, atomically: true, encoding: .utf8)
        try "not a cue".write(to: bad, atomically: true, encoding: .utf8)
        try "sentinel".write(to: existing, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ConversionEngine().convert(.init(inputs: [valid, bad], target: .vtt)))
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "sentinel")
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertFalse(names.contains { $0.hasPrefix("valid-") && $0.hasSuffix(".vtt") })
        XCTAssertFalse(names.contains { $0.hasPrefix(".OrbitMorph-") })
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FormatExpansion-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
