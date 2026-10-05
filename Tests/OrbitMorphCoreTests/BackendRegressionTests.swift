import AppKit
import Foundation
import PDFKit
import XCTest
@testable import OrbitMorphCore

final class BackendRegressionTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphRegression-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func command(_ path: String, _ arguments: [String]) throws -> String {
        try ProcessRunner.run(.init(executable: path, arguments: arguments)).output
    }

    func testRegistryOnlyOffersReadableDocumentRoutesAndAvailableArchives() {
        let deps = DependencyResolver(overrides: ["pandoc": "/opt/homebrew/bin/pandoc", "textutil": "/usr/bin/textutil", "7zz": nil, "ditto": "/usr/bin/ditto", "tar": "/usr/bin/tar"])
        let registry = ConversionRegistry(dependencies: deps)
        XCTAssertEqual(registry.route(from: .pdf, to: .docx)?.backend, .nativeText)
        XCTAssertNil(registry.route(from: .doc, to: .md))
        XCTAssertNil(registry.route(from: .txt, to: .md))
        XCTAssertEqual(registry.route(from: .doc, to: .docx)?.backend, .textutil)
        XCTAssertEqual(registry.route(from: .md, to: .docx)?.backend, .pandoc)
        XCTAssertNotNil(registry.route(from: .zip, to: .tar))
        XCTAssertNil(registry.route(from: .zip, to: .sevenZ))
        XCTAssertEqual(registry.targets(for: .sevenZ), [])
    }

    func testPDFRendersEveryPageAsSeparatePNG() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("two pages.pdf")
        let document = PDFDocument()
        for color in [NSColor.red, NSColor.blue] {
            let image = NSImage(size: NSSize(width: 60, height: 40))
            image.lockFocus(); color.setFill(); NSRect(x: 0, y: 0, width: 60, height: 40).fill(); image.unlockFocus()
            document.insert(try XCTUnwrap(PDFPage(image: image)), at: document.pageCount)
        }
        XCTAssertTrue(document.write(to: source))
        let results = try ConversionEngine().convert(.init(inputs: [source], target: .png, outputDirectory: root))
        XCTAssertEqual(results.map(\.outputURL.lastPathComponent), ["two pages-page-1.png", "two pages-page-2.png"])
        for result in results {
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: result.outputURL)))
            XCTAssertGreaterThan(bitmap.pixelsWide, 50)
            XCTAssertGreaterThan(bitmap.pixelsHigh, 30)
        }
    }

    func testNativeArchiveFallbackKeepsPayloadAtRoot() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let payload = root.appendingPathComponent("payload.txt")
        try "contents".write(to: payload, atomically: true, encoding: .utf8)
        let source = root.appendingPathComponent("input.zip")
        _ = try ProcessRunner.run(.init(executable: "/usr/bin/zip", arguments: ["-q", source.path, "payload.txt"], workingDirectory: root))
        let deps = DependencyResolver(overrides: ["7zz": nil])
        let output = try XCTUnwrap(ConversionEngine(dependencies: deps).convert(.init(inputs: [source], target: .tar, outputDirectory: root)).first?.outputURL)
        let listing = try command("/usr/bin/tar", ["-tf", output.path])
        XCTAssertTrue(listing.split(separator: "\n").contains(where: { $0 == "./payload.txt" || $0 == "payload.txt" }), listing)
        XCTAssertFalse(listing.contains("OrbitMorphArchive-"), listing)
    }

    func testTarGzAliasExtractsPayloadRatherThanNestedTar() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let payload = root.appendingPathComponent("payload.txt")
        try "nested archive".write(to: payload, atomically: true, encoding: .utf8)
        let source = root.appendingPathComponent("input.tar.gz")
        _ = try ProcessRunner.run(.init(executable: "/usr/bin/tar", arguments: ["-czf", source.path, "payload.txt"], workingDirectory: root))
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [source], target: .zip, outputDirectory: root)).first?.outputURL)
        let listing = try command("/usr/bin/zipinfo", ["-1", output.path])
        XCTAssertTrue(listing.split(separator: "\n").contains("payload.txt"), listing)
        XCTAssertFalse(listing.contains("input.tar"), listing)
    }

    func testNativeTarToZipPreservesPayloadRoot() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let payload = root.appendingPathComponent("payload.txt")
        try "archive payload".write(to: payload, atomically: true, encoding: .utf8)
        let source = root.appendingPathComponent("input.tar")
        _ = try ProcessRunner.run(.init(executable: "/usr/bin/tar", arguments: ["-cf", source.path, "payload.txt"], workingDirectory: root))
        let deps = DependencyResolver(overrides: ["7zz": nil])
        let output = try XCTUnwrap(ConversionEngine(dependencies: deps).convert(.init(inputs: [source], target: .zip, outputDirectory: root)).first?.outputURL)
        let listing = try command("/usr/bin/zipinfo", ["-1", output.path])
        XCTAssertTrue(listing.split(separator: "\n").contains("payload.txt"), listing)
        XCTAssertFalse(listing.contains("OrbitMorphArchive-"), listing)
    }

    func testProcessRunnerTerminatesHungConverter() {
        let start = Date()
        let invocation = ProcessInvocation(executable: "/bin/sleep", arguments: ["5"])
        XCTAssertThrowsError(try ProcessRunner.run(invocation, timeout: 0.1)) { error in
            guard case ProcessRunnerError.timedOut = error else {
                return XCTFail("Expected a timeout, got \(error)")
            }
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testAnimatedGIFToPNGWritesOneFirstFrameWithoutTemporarySiblings() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("animated.gif")
        _ = try command("/opt/homebrew/bin/magick", ["-size", "8x8", "xc:red", "-size", "8x8", "xc:blue", "-loop", "0", source.path])
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [source], target: .png, outputDirectory: root)).first?.outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), ["animated.gif", "animated.png"])
    }

    func testNativeImageIOFallbackConvertsWithoutImageMagick() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("native.png")
        _ = try command("/opt/homebrew/bin/magick", ["-size", "12x10", "xc:green", source.path])
        let deps = DependencyResolver(overrides: ["magick": nil])
        let registry = ConversionRegistry(dependencies: deps)
        XCTAssertNotNil(registry.route(from: .png, to: .jpg))
        let output = try XCTUnwrap(ConversionEngine(dependencies: deps).convert(.init(inputs: [source], target: .jpg, outputDirectory: root)).first?.outputURL)
        let format = try command("/opt/homebrew/bin/magick", ["identify", "-format", "%m", output.path])
        XCTAssertEqual(format, "JPEG")
    }

    func testPerInputOutputDirectoriesAndCrossDirectoryRollback() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.png"), second = root.appendingPathComponent("second.png")
        let firstFolder = root.appendingPathComponent("images-a"), secondFolder = root.appendingPathComponent("images-b")
        try FileManager.default.createDirectory(at: firstFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondFolder, withIntermediateDirectories: true)
        _ = try command("/opt/homebrew/bin/magick", ["-size", "8x8", "xc:red", first.path])
        _ = try command("/opt/homebrew/bin/magick", ["-size", "8x8", "xc:blue", second.path])
        let folders = [first: firstFolder, second: secondFolder]
        let engine = ConversionEngine()
        let results = try engine.convert(.init(inputs: [first, second], target: .jpg, outputDirectories: folders))
        XCTAssertEqual(results.map { $0.outputURL.deletingLastPathComponent().path }, [firstFolder.path, secondFolder.path])
        for result in results { try FileManager.default.removeItem(at: result.outputURL) }
        try "broken".write(to: second, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try engine.convert(.init(inputs: [first, second], target: .jpg, outputDirectories: folders)))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: firstFolder.path), [])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: secondFolder.path), [])
    }

    func testFailedConversionRemovesTemporaryOutputAndEarlierBatchResults() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let good = root.appendingPathComponent("good.png")
        let bad = root.appendingPathComponent("bad.png")
        _ = try command("/opt/homebrew/bin/magick", ["-size", "8x8", "xc:red", good.path])
        try "invalid image".write(to: bad, atomically: true, encoding: .utf8)
        let engine = ConversionEngine(dependencies: DependencyResolver())
        XCTAssertThrowsError(try engine.convert(.init(inputs: [good, bad], target: .jpg, outputDirectory: root)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("good.jpg").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("bad.jpg").path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), ["bad.png", "good.png"])
    }

    func testArchiveExtractionRejectsSymlinkAndHardlinkMembers() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        for kind in ["symlink", "hardlink"] {
            let archive = root.appendingPathComponent("\(kind).tar")
            let script = "import tarfile,sys; t=tarfile.open(sys.argv[1], 'w'); i=tarfile.TarInfo('link'); i.type=tarfile.SYMTYPE if sys.argv[2]=='symlink' else tarfile.LNKTYPE; i.linkname='../outside'; t.addfile(i); t.close()"
            _ = try command("/opt/homebrew/bin/python3", ["-c", script, archive.path, kind])
            let destination = root.appendingPathComponent("extract-\(kind)")
            XCTAssertThrowsError(try ArchiveAdapter.extract(input: archive, into: destination, dependencies: DependencyResolver(overrides: ["7zz": nil])))
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        }
    }

    func testSevenZipSymlinkMemberIsRejected() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "../outside"))
        let archive = root.appendingPathComponent("links.7z")
        _ = try ProcessRunner.run(.init(executable: "/opt/homebrew/bin/7zz", arguments: ["a", "-t7z", "-snl", archive.path, "link"], workingDirectory: root))
        let destination = root.appendingPathComponent("extract")
        XCTAssertThrowsError(try ArchiveAdapter.extract(input: archive, into: destination, dependencies: DependencyResolver()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testArchiveExtractionRejectsParentTraversalBeforeWritingFiles() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("malicious.tar")
        let script = "import tarfile,io,sys; t=tarfile.open(sys.argv[1], 'w'); i=tarfile.TarInfo('../escaped.txt'); b=b'unsafe'; i.size=len(b); t.addfile(i, io.BytesIO(b)); t.close()"
        _ = try command("/opt/homebrew/bin/python3", ["-c", script, archive.path])
        let destination = root.appendingPathComponent("extract")
        XCTAssertThrowsError(try ArchiveAdapter.extract(input: archive, into: destination, dependencies: DependencyResolver(overrides: ["7zz": nil])))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("escaped.txt").path))
    }

    func testFailedExtractionRemovesNewDestinationDirectory() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("fake.7z")
        try Data().write(to: input)
        let script = root.appendingPathComponent("fake-7zz.sh")
        let body = "#!/bin/sh\nif [ \"$1\" = \"l\" ]; then printf '%s\\n' '----------' 'Path = payload.txt'; exit 0; fi\nfor item do case \"$item\" in -o*) destination=\"${item#-o}\";; esac; done\nprintf partial > \"$destination/payload.txt\"\nexit 9\n"
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let destination = root.appendingPathComponent("extracted")
        XCTAssertThrowsError(try ArchiveAdapter.extract(input: input, into: destination, dependencies: DependencyResolver(overrides: ["7zz": script.path])))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testTextutilConvertsDOCAndRTFInBothDirections() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("memo.txt")
        try "OrbitMorph plain text".write(to: input, atomically: true, encoding: .utf8)
        let engine = ConversionEngine()
        let doc = try XCTUnwrap(engine.convert(.init(inputs: [input], target: .doc, outputDirectory: root)).first?.outputURL)
        let rtf = try XCTUnwrap(engine.convert(.init(inputs: [doc], target: .rtf, outputDirectory: root)).first?.outputURL)
        let text = try XCTUnwrap(engine.convert(.init(inputs: [rtf], target: .txt, outputDirectory: root)).first?.outputURL)
        XCTAssertTrue(try String(contentsOf: text, encoding: .utf8).contains("OrbitMorph plain text"))
    }

    func testSevenZipToTGZPreservesPayloadRoot() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let payload = root.appendingPathComponent("payload.txt")
        try "archive chain".write(to: payload, atomically: true, encoding: .utf8)
        let archive = root.appendingPathComponent("input.7z")
        _ = try ProcessRunner.run(.init(executable: "/opt/homebrew/bin/7zz", arguments: ["a", "-t7z", archive.path, "payload.txt"], workingDirectory: root))
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [archive], target: .tgz, outputDirectory: root)).first?.outputURL)
        let listing = try command("/usr/bin/tar", ["-tzf", output.path])
        XCTAssertTrue(listing.split(separator: "\n").contains(where: { $0 == "./payload.txt" || $0 == "payload.txt" }), listing)
    }

    func testExternalOutputCreatedDuringConversionIsNeverOverwritten() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("race.png")
        _ = try command("/opt/homebrew/bin/magick", ["-size", "8x8", "xc:red", source.path])
        let original = try Data(contentsOf: source)
        let script = root.appendingPathComponent("fake-magick.sh")
        try "#!/bin/sh\ncase \"$1\" in */race.png*) printf external > \"${1%.*}.jpg\";; esac\nexec /opt/homebrew/bin/magick \"$@\"\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let deps = DependencyResolver(overrides: ["magick": script.path])
        let output = try XCTUnwrap(ConversionEngine(dependencies: deps).convert(.init(inputs: [source], target: .jpg, outputDirectory: root)).first?.outputURL)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("race.jpg"), encoding: .utf8), "external")
        XCTAssertEqual(output.lastPathComponent, "race-converted.jpg")
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: output)))
        XCTAssertEqual(bitmap.pixelsWide, 8)
        XCTAssertEqual(bitmap.pixelsHigh, 8)
        XCTAssertEqual(try Data(contentsOf: source), original)
    }

    func testSilentVideoConvertsToVideoButRejectsAudioExtractionCleanly() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("silent.mov")
        _ = try command("/opt/homebrew/bin/ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=blue:s=64x64:d=0.4", "-c:v", "libx264", "-an", source.path])
        let engine = ConversionEngine()
        let video = try XCTUnwrap(engine.convert(.init(inputs: [source], target: .mp4, outputDirectory: root)).first?.outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: video.path))
        XCTAssertThrowsError(try engine.convert(.init(inputs: [source], target: .mp3, outputDirectory: root)))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), ["silent.mov", "silent.mp4"])
    }

    func testOGGConversionUsesAvailableVorbisEncoder() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.wav")
        _ = try command("/opt/homebrew/bin/ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=600:duration=0.4", source.path])
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [source], target: .ogg, outputDirectory: root)).first?.outputURL)
        let codec = try command("/opt/homebrew/bin/ffprobe", ["-v", "error", "-show_entries", "stream=codec_name", "-of", "default=nw=1:nk=1", output.path])
        XCTAssertEqual(codec.trimmingCharacters(in: .whitespacesAndNewlines), "vorbis")
    }

    func testConfiguredAudioBitrateIsAppliedToEveryAudioEncodingTarget() {
        let options = FormatDefaults(audioBitrateKbps: 96)
        let input = URL(fileURLWithPath: "/tmp/source.mov")
        for target in [FormatID.mp4, .m4v, .mov, .mkv, .webm, .avi, .ogg] {
            let output = URL(fileURLWithPath: "/tmp/output.\(target.fileExtension)")
            let args = FFmpegAdapter.invocation(input: input, output: output, target: target, ffmpegPath: "/bin/ffmpeg", options: options).arguments
            XCTAssertTrue(args.windows(ofCount: 2).contains(["-b:a", "96k"]), "Missing bitrate for \(target): \(args)")
        }
    }

    func testVideoConversionHonorsAudioBitrateOption() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("source.mov")
        _ = try command("/opt/homebrew/bin/ffmpeg", ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=red:s=64x64:d=1.2", "-f", "lavfi", "-i", "sine=frequency=1000:duration=1.2", "-c:v", "libx264", "-c:a", "aac", "-shortest", input.path])
        let options = FormatDefaults(audioBitrateKbps: 96)
        let output = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .mp4, outputDirectory: root, options: options)).first?.outputURL)
        let rate = try command("/opt/homebrew/bin/ffprobe", ["-v", "error", "-select_streams", "a:0", "-show_entries", "stream=bit_rate", "-of", "default=nw=1:nk=1", output.path])
        let parsed = try XCTUnwrap(Int(rate.trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertGreaterThan(parsed, 50_000)
        XCTAssertLessThan(parsed, 150_000)
    }

    func testJobOptionsReachImageAndMediaAdapters() {
        let options = FormatDefaults(quality: 0.71, audioBitrateKbps: 128, videoPreset: "slow", preserveMetadata: false, archiveLevel: 3)
        let job = ConversionJob(inputs: [], target: .jpg, options: options)
        let image = ImageMagickAdapter.invocation(input: URL(fileURLWithPath: "/tmp/in.png"), output: URL(fileURLWithPath: "/tmp/out.jpg"), target: .jpg, magickPath: "/bin/magick", options: job.options)
        XCTAssertTrue(image.arguments.windows(ofCount: 2).contains(["-quality", "71"]))
        XCTAssertTrue(image.arguments.contains("-strip"))
        let media = FFmpegAdapter.invocation(input: URL(fileURLWithPath: "/tmp/in.mov"), output: URL(fileURLWithPath: "/tmp/out.mp4"), target: .mp4, ffmpegPath: "/bin/ffmpeg", options: options)
        XCTAssertTrue(media.arguments.windows(ofCount: 2).contains(["-preset", "slow"]))
        XCTAssertTrue(media.arguments.windows(ofCount: 2).contains(["-map_metadata", "-1"]))
        let audio = FFmpegAdapter.invocation(input: URL(fileURLWithPath: "/tmp/in.wav"), output: URL(fileURLWithPath: "/tmp/out.m4a"), target: .m4a, ffmpegPath: "/bin/ffmpeg", options: options)
        XCTAssertTrue(audio.arguments.windows(ofCount: 2).contains(["-b:a", "128k"]))
    }
}

private extension Array where Element == String {
    func windows(ofCount count: Int) -> [[String]] {
        guard self.count >= count else { return [] }
        return (0...(self.count - count)).map { Array(self[$0..<$0 + count]) }
    }
}
