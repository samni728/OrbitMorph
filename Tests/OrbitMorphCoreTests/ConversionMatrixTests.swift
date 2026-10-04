import AppKit
import PDFKit
import XCTest
@testable import OrbitMorphCore

final class ConversionMatrixTests: XCTestCase {
    func testEveryAdvertisedRouteWithGeneratedFixture() throws {
        guard ProcessInfo.processInfo.environment["ORBITMORPH_FULL_MATRIX"] == "1" else {
            throw XCTSkip("Set ORBITMORPH_FULL_MATRIX=1 to run the full local converter matrix")
        }
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("OrbitMorphMatrix-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let fixtures = try makeFixtures(in: root)
        let registry = ConversionRegistry()
        let engine = ConversionEngine()
        var failures: [String] = []
        var passed: [String] = []
        var advertised = 0
        var unverifiedPairs: [String] = []
        for source in FormatID.allCases {
            let routes = registry.routes(for: source)
            advertised += routes.count
            guard let input = fixtures[source] else {
                unverifiedPairs += routes.map { "\(source.rawValue)→\($0.target.rawValue)" }
                continue
            }
            let outputDirectory = root.appendingPathComponent("out-\(source.rawValue)")
            try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            for route in routes {
                let label = "\(source.rawValue)→\(route.target.rawValue)"
                do {
                    let results = try engine.convert(.init(inputs: [input], target: route.target, outputDirectory: outputDirectory))
                    guard !results.isEmpty else { throw MatrixFailure("No output") }
                    let archiveEntry = source == .rar ? "helloworld.txt" : "payload.txt"
                    for result in results {
                        try validate(result.outputURL, target: route.target, in: root, expectedArchiveEntry: archiveEntry)
                    }
                    passed.append(label)
                } catch {
                    failures.append("\(label): \(error.localizedDescription)")
                }
            }
        }
        let report: [String: Any] = [
            "advertisedRoutes": advertised,
            "testedRoutes": passed.count + failures.count,
            "passedRoutes": passed.count,
            "failedRoutes": failures,
            "unverifiedPairs": unverifiedPairs,
            "rarFixture": "libarchive/test/test_read_format_rar5_stored.rar.uu",
            "passedPairs": passed
        ]
        let reportURL = fm.temporaryDirectory.appendingPathComponent("orbitmorph-matrix-report.json")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL)
        print("Conversion matrix report: \(reportURL.path)")
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
        XCTAssertTrue(unverifiedPairs.isEmpty, "Unverified routes: \(unverifiedPairs.joined(separator: ", "))")
    }

    private func makeFixtures(in root: URL) throws -> [FormatID: URL] {
        var fixtures: [FormatID: URL] = [:]
        let png = root.appendingPathComponent("source.png")
        _ = try run("/opt/homebrew/bin/magick", ["-size", "16x12", "xc:#f15b42", png.path])
        fixtures[.png] = png
        let svg = root.appendingPathComponent("source.svg")
        try "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"12\"><rect width=\"16\" height=\"12\" fill=\"#f15b42\"/></svg>"
            .write(to: svg, atomically: true, encoding: .utf8)
        fixtures[.svg] = svg
        for format in [FormatID.jpg, .webp, .heic, .tiff, .avif, .bmp, .gif] {
            let output = root.appendingPathComponent("source.\(format.fileExtension)")
            _ = try run("/opt/homebrew/bin/magick", [png.path, output.path])
            fixtures[format] = output
        }
        let image = NSImage(size: NSSize(width: 16, height: 12))
        image.lockFocus(); NSColor.orange.setFill(); NSRect(x: 0, y: 0, width: 16, height: 12).fill(); image.unlockFocus()
        let pdf = PDFDocument()
        pdf.insert(try XCTUnwrap(PDFPage(image: image)), at: 0)
        let pdfURL = root.appendingPathComponent("source.pdf")
        XCTAssertTrue(pdf.write(to: pdfURL))
        fixtures[.pdf] = pdfURL

        let txt = root.appendingPathComponent("source.txt")
        try "OrbitMorph matrix document\n".write(to: txt, atomically: true, encoding: .utf8)
        fixtures[.txt] = txt
        let md = root.appendingPathComponent("source.md")
        try "# OrbitMorph matrix document\n".write(to: md, atomically: true, encoding: .utf8)
        fixtures[.md] = md
        let html = root.appendingPathComponent("source.html")
        try "<p>OrbitMorph matrix document</p>".write(to: html, atomically: true, encoding: .utf8)
        fixtures[.html] = html
        for format in [FormatID.doc, .docx, .rtf, .odt] {
            let output = root.appendingPathComponent("source.\(format.fileExtension)")
            _ = try run("/usr/bin/textutil", ["-convert", format.fileExtension, "-output", output.path, txt.path])
            fixtures[format] = output
        }
        let srt = root.appendingPathComponent("source.srt")
        try "1\n00:00:01,000 --> 00:00:02,500\nOrbitMorph 字幕\nsecond line\n"
            .write(to: srt, atomically: true, encoding: .utf8)
        fixtures[.srt] = srt
        let vtt = root.appendingPathComponent("source.vtt")
        try "WEBVTT\n\ncue-one\n00:01.000 --> 00:02.500\nOrbitMorph 字幕\nsecond line\n"
            .write(to: vtt, atomically: true, encoding: .utf8)
        fixtures[.vtt] = vtt

        let wav = root.appendingPathComponent("source.wav")
        _ = try run("/opt/homebrew/bin/ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=600:duration=0.35", wav.path])
        fixtures[.wav] = wav
        for format in [FormatID.mp3, .m4a, .aac, .flac, .ogg, .opus, .aiff, .wma] {
            let output = root.appendingPathComponent("source.\(format.fileExtension)")
            var args = ["-hide_banner", "-loglevel", "error", "-y", "-i", wav.path]
            if format == .wma { args += ["-c:a", "wmav2"] }
            args.append(output.path)
            _ = try run("/opt/homebrew/bin/ffmpeg", args)
            fixtures[format] = output
        }
        let mov = root.appendingPathComponent("source.mov")
        _ = try run("/opt/homebrew/bin/ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=blue:s=64x64:d=0.35", "-f", "lavfi", "-i", "sine=frequency=600:duration=0.35", "-c:v", "libx264", "-c:a", "aac", "-shortest", mov.path])
        fixtures[.mov] = mov
        for format in [FormatID.mp4, .mkv, .webm, .avi, .m4v, .wmv] {
            let output = root.appendingPathComponent("source.\(format.fileExtension)")
            var args = ["-hide_banner", "-loglevel", "error", "-y", "-i", mov.path]
            if format == .wmv { args += ["-c:v", "wmv2", "-c:a", "wmav2"] }
            args.append(output.path)
            _ = try run("/opt/homebrew/bin/ffmpeg", args)
            fixtures[format] = output
        }

        let payload = root.appendingPathComponent("payload.txt")
        try "OrbitMorph archive payload".write(to: payload, atomically: true, encoding: .utf8)
        let zip = root.appendingPathComponent("source.zip")
        _ = try run("/usr/bin/zip", ["-q", zip.path, "payload.txt"], workingDirectory: root)
        fixtures[.zip] = zip
        let sevenZ = root.appendingPathComponent("source.7z")
        _ = try run("/opt/homebrew/bin/7zz", ["a", "-t7z", sevenZ.path, "payload.txt"], workingDirectory: root)
        fixtures[.sevenZ] = sevenZ
        for format in [FormatID.tar, .tgz] {
            let output = root.appendingPathComponent("source.\(format.fileExtension)")
            _ = try run("/usr/bin/tar", [format == .tgz ? "-czf" : "-cf", output.path, "payload.txt"], workingDirectory: root)
            fixtures[format] = output
        }
        _ = try run("/usr/bin/gzip", ["-k", "-f", payload.path])
        let gz = root.appendingPathComponent("source.gz")
        try FileManager.default.moveItem(at: root.appendingPathComponent("payload.txt.gz"), to: gz)
        fixtures[.gz] = gz

        // Official libarchive test fixture: https://github.com/libarchive/libarchive/blob/master/libarchive/test/test_read_format_rar5_stored.rar.uu
        let uuFixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/libarchive-rar5-stored.rar.uu")
        let rar = root.appendingPathComponent("source.rar")
        _ = try run("/usr/bin/uudecode", ["-o", rar.path, uuFixture.path])
        fixtures[.rar] = rar
        return fixtures
    }

    private func validate(_ output: URL, target: FormatID, in root: URL, expectedArchiveEntry: String) throws {
        let size = (try FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 else { throw MatrixFailure("Empty output: \(output.path)") }
        if target == .pdf {
            guard let pdf = PDFDocument(url: output), pdf.pageCount > 0 else { throw MatrixFailure("Unreadable PDF") }
        } else if target.kind == .image {
            let result = try run("/opt/homebrew/bin/magick", ["identify", "-format", "%m", output.path])
            guard !result.isEmpty else { throw MatrixFailure("Unreadable image") }
        } else if target.kind == .audio || target.kind == .video {
            let result = try run("/opt/homebrew/bin/ffprobe", ["-v", "error", "-show_entries", "stream=codec_type", "-of", "csv=p=0", output.path])
            let required = target.kind == .video ? "video" : "audio"
            guard result.contains(required) else { throw MatrixFailure("Missing \(required) stream") }
            if target == .wmv || target == .wma {
                let codecs = try run("/opt/homebrew/bin/ffprobe", ["-v", "error", "-show_entries", "stream=codec_name", "-of", "csv=p=0", output.path])
                guard codecs.contains("wmav2"), target != .wmv || codecs.contains("wmv2") else {
                    throw MatrixFailure("Wrong Windows Media codecs: \(codecs)")
                }
            }
        } else if target.kind == .subtitle {
            let content = try String(contentsOf: output, encoding: .utf8)
            guard content.contains("OrbitMorph 字幕"), content.contains("second line"),
                  content.contains(target == .vtt ? "00:00:01.000 --> 00:00:02.500" : "00:00:01,000 --> 00:00:02,500") else {
                throw MatrixFailure("Subtitle content or timing missing")
            }
        } else if target.kind == .archive {
            let extracted = root.appendingPathComponent("check-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: extracted) }
            try ArchiveAdapter.extract(input: output, into: extracted, dependencies: .init())
            guard FileManager.default.fileExists(atPath: extracted.appendingPathComponent(expectedArchiveEntry).path) else {
                throw MatrixFailure("Payload absent from archive root")
            }
        } else if target == .txt || target == .md {
            let content = try String(contentsOf: output, encoding: .utf8)
            guard content.contains("OrbitMorph") else { throw MatrixFailure("Text content missing") }
        } else {
            let content = try run("/usr/bin/textutil", ["-convert", "txt", "-stdout", output.path])
            guard content.contains("OrbitMorph") else { throw MatrixFailure("Document content missing") }
        }
    }

    private func run(_ executable: String, _ arguments: [String], workingDirectory: URL? = nil) throws -> String {
        try ProcessRunner.run(.init(executable: executable, arguments: arguments, workingDirectory: workingDirectory)).output
    }
}

private struct MatrixFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
