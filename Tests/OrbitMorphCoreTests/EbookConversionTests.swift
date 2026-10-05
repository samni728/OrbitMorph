import Foundation
import PDFKit
import XCTest
@testable import OrbitMorphCore

final class EbookConversionTests: XCTestCase {
    func testMissingCalibreDoesNotAdvertiseEbookRoutes() {
        let registry = ConversionRegistry(dependencies: .init(overrides: ["ebook-convert": nil]))
        for source in [FormatID.epub, .mobi, .azw3] {
            XCTAssertTrue(registry.targets(for: source).isEmpty)
        }
    }

    func testTwoChapterEbooksConvertAcrossFamiliesAndDocumentOutputs() throws {
        let dependencies = try availableDependencies()
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = try EbookTestFixtures.make(in: root, dependencies: dependencies)
        let path = try XCTUnwrap(dependencies.path(for: "ebook-convert"))
        for source in [FormatID.epub, .mobi, .azw3] {
            for target in [FormatID.epub, .mobi, .azw3, .txt, .docx, .pdf] where target != source {
                let output = root.appendingPathComponent("\(source.rawValue)-to-\(target.rawValue).\(target.fileExtension)")
                try CalibreAdapter.convert(input: XCTUnwrap(fixtures[source]), output: output,
                                          source: source, target: target, ebookConvertPath: path)
                try EbookTestFixtures.validate(output: output, target: target, root: root, dependencies: dependencies)
            }
        }
    }

    func testPlainHTMLAndDOCXInputsBecomeReadableEbooks() throws {
        let dependencies = try availableDependencies()
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = try EbookTestFixtures.make(in: root, dependencies: dependencies)
        let path = try XCTUnwrap(dependencies.path(for: "ebook-convert"))
        for source in [FormatID.txt, .html, .docx] {
            for target in [FormatID.epub, .mobi, .azw3] {
                let output = root.appendingPathComponent("\(source.rawValue)-to-\(target.rawValue).\(target.fileExtension)")
                try CalibreAdapter.convert(input: XCTUnwrap(fixtures[source]), output: output,
                                          source: source, target: target, ebookConvertPath: path)
                try EbookTestFixtures.validate(output: output, target: target, root: root, dependencies: dependencies)
            }
        }
    }

    func testUnicodeInputAndExistingOutputArePreserved() throws {
        let dependencies = try availableDependencies()
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("中文 空格 '书籍'.txt")
        let original = Data("Chapter One 第一章\nOrbitMorphAlpha\n\nChapter Two 第二章\nOrbitMorphBeta\n".utf8)
        try original.write(to: input)
        let existing = root.appendingPathComponent("中文 空格 '书籍'.epub")
        let sentinel = Data("Existing output must survive".utf8)
        try sentinel.write(to: existing)
        let results = try ConversionEngine(dependencies: dependencies).convert(.init(inputs: [input], target: .epub))
        let output = try XCTUnwrap(results.first?.outputURL)
        XCTAssertNotEqual(output, existing)
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(try Data(contentsOf: existing), sentinel)
        try EbookTestFixtures.validate(output: output, target: .epub, root: root, dependencies: dependencies)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".OrbitMorph-") })
    }

    func testCorruptInputFailsWithoutChangingInputOrLeavingOutput() throws {
        let dependencies = try availableDependencies()
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("corrupt.epub")
        let original = Data("This is not an EPUB archive".utf8)
        try original.write(to: input)
        let output = root.appendingPathComponent("corrupt.mobi")
        XCTAssertThrowsError(try CalibreAdapter.convert(input: input, output: output,
            source: .epub, target: .mobi, ebookConvertPath: XCTUnwrap(dependencies.path(for: "ebook-convert"))))
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testDirectAdapterRefusesToOverwriteExistingOutput() throws {
        let dependencies = try availableDependencies()
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("source.txt")
        try "Original text".write(to: input, atomically: true, encoding: .utf8)
        let output = root.appendingPathComponent("existing.epub")
        let sentinel = Data("sentinel".utf8)
        try sentinel.write(to: output)
        XCTAssertThrowsError(try CalibreAdapter.convert(input: input, output: output,
            source: .txt, target: .epub, ebookConvertPath: XCTUnwrap(dependencies.path(for: "ebook-convert"))))
        XCTAssertEqual(try Data(contentsOf: output), sentinel)
    }

    func testSuccessfulConverterWithInvalidBookDoesNotPublishOrLeakScratchDirectory() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("source.txt")
        try "Source content".write(to: input, atomically: true, encoding: .utf8)
        let invalid = root.appendingPathComponent("invalid-book.bin")
        var header = Data(repeating: 0, count: 106)
        header.replaceSubrange(60..<68, with: Data("BOOKMOBI".utf8))
        header[77] = 1
        header[81] = 86
        header.replaceSubrange(102..<106, with: Data("MOBI".utf8))
        try header.write(to: invalid)
        let scratchRecord = root.appendingPathComponent("scratch-path.txt")
        let executable = root.appendingPathComponent("ebook-convert")
        try "#!/bin/sh\n/bin/cp '\(invalid.path)' \"$2\"\n/usr/bin/printf '%s' \"$PWD\" > '\(scratchRecord.path)'\n"
            .write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let output = root.appendingPathComponent("bad.mobi")
        XCTAssertThrowsError(try CalibreAdapter.convert(input: input, output: output,
            source: .txt, target: .mobi, ebookConvertPath: executable.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        let scratchPath = try String(contentsOf: scratchRecord, encoding: .utf8)
        XCTAssertFalse(FileManager.default.fileExists(atPath: scratchPath))
    }

    private func availableDependencies() throws -> DependencyResolver {
        let dependencies = DependencyResolver()
        guard dependencies.has("ebook-convert") else { throw XCTSkip("Calibre ebook-convert is not installed") }
        return dependencies
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorph-EbookTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

enum EbookTestFixtures {
    static func make(in root: URL, dependencies: DependencyResolver) throws -> [FormatID: URL] {
        guard let calibre = dependencies.path(for: "ebook-convert") else {
            throw ConversionEngineError.missingDependency("ebook-convert")
        }
        let package = root.appendingPathComponent("epub-package-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: package) }
        let oebps = package.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: package.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oebps, withIntermediateDirectories: true)
        try write("application/epub+zip", to: package.appendingPathComponent("mimetype"))
        try write("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>
        """, to: package.appendingPathComponent("META-INF/container.xml"))
        try write("""
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="book-id">urn:uuid:orbitmorph-test-book</dc:identifier><dc:title>OrbitMorph 双章节测试</dc:title><dc:creator>OrbitMorph Test Author</dc:creator><dc:language>zh-CN</dc:language><meta property="dcterms:modified">2026-10-04T00:00:00Z</meta></metadata>
        <manifest><item id="one" href="chapter1.xhtml" media-type="application/xhtml+xml"/><item id="two" href="chapter2.xhtml" media-type="application/xhtml+xml"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="cover" href="cover.png" media-type="image/png" properties="cover-image"/></manifest>
        <spine><itemref idref="one"/><itemref idref="two"/></spine></package>
        """, to: oebps.appendingPathComponent("content.opf"))
        try write("""
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>目录</title></head><body><nav epub:type="toc" id="toc"><h1>目录</h1><ol><li><a href="chapter1.xhtml">第一章</a></li><li><a href="chapter2.xhtml">第二章</a></li></ol></nav></body></html>
        """, to: oebps.appendingPathComponent("nav.xhtml"))
        let bodies = [
            "<h1>Chapter One 第一章</h1><p>OrbitMorphAlpha 你好世界</p><img src=\"cover.png\" alt=\"Test cover\"/>",
            "<h1>Chapter Two 第二章</h1><p>OrbitMorphBeta 中文测试</p>"
        ]
        for (index, body) in bodies.enumerated() {
            try write("<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>Chapter \(index + 1)</title></head><body>\(body)</body></html>",
                      to: oebps.appendingPathComponent("chapter\(index + 1).xhtml"))
        }
        let cover = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAE0lEQVR4nGP438AARAwMDf+BCAAp8gX9AiY2+QAAAABJRU5ErkJggg=="))
        try cover.write(to: oebps.appendingPathComponent("cover.png"))
        let epub = root.appendingPathComponent("ebook-source.epub")
        try ProcessRunner.run(.init(executable: "/usr/bin/zip", arguments: ["-q", "-0", epub.path, "mimetype"], workingDirectory: package))
        try ProcessRunner.run(.init(executable: "/usr/bin/zip", arguments: ["-q", "-r", epub.path, "META-INF", "OEBPS"], workingDirectory: package))
        var fixtures: [FormatID: URL] = [.epub: epub]
        for target in [FormatID.mobi, .azw3, .docx] {
            let output = root.appendingPathComponent("ebook-source.\(target.fileExtension)")
            try runCalibre(input: epub, output: output, calibre: calibre, root: root)
            fixtures[target] = output
        }
        let txt = root.appendingPathComponent("ebook-source.txt")
        try write("Chapter One 第一章\nOrbitMorphAlpha 你好世界\n\nChapter Two 第二章\nOrbitMorphBeta 中文测试\n", to: txt)
        fixtures[.txt] = txt
        let html = root.appendingPathComponent("ebook-source.html")
        try write("<!DOCTYPE html><html><head><meta charset=\"utf-8\"/><title>OrbitMorph 双章节测试</title></head><body>\(bodies.joined())</body></html>", to: html)
        // The HTML fixture embeds its image beside the input rather than depending on the removed EPUB package.
        try cover.write(to: root.appendingPathComponent("cover.png"))
        fixtures[.html] = html
        return fixtures
    }

    static func validate(output: URL, target: FormatID, root: URL, dependencies: DependencyResolver,
                         expectedText: [String] = ["OrbitMorphAlpha", "OrbitMorphBeta", "第一章", "第二章"]) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? 0 > 0 else { throw EbookFixtureError("Empty ebook output") }
        let text: String
        if target == .txt {
            text = try String(contentsOf: output, encoding: .utf8)
        } else if target == .pdf {
            guard let document = PDFDocument(url: output), document.pageCount > 0 else { throw EbookFixtureError("Unreadable PDF") }
            text = document.string ?? ""
        } else {
            guard let calibre = dependencies.path(for: "ebook-convert") else { throw ConversionEngineError.missingDependency("ebook-convert") }
            let check = root.appendingPathComponent("ebook-check-\(UUID().uuidString).txt")
            defer { try? FileManager.default.removeItem(at: check) }
            try runCalibre(input: output, output: check, calibre: calibre, root: root)
            text = try String(contentsOf: check, encoding: .utf8)
        }
        for marker in expectedText {
            guard text.contains(marker) else { throw EbookFixtureError("Missing ebook content: \(marker) in \(target.rawValue)") }
        }
        if target == .epub {
            let mimetype = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, "mimetype"])).output
            guard mimetype == "application/epub+zip" else { throw EbookFixtureError("Wrong EPUB MIME type") }
            let listing = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-Z1", output.path])).output
            guard listing.contains("META-INF/container.xml"), listing.contains(".opf") else { throw EbookFixtureError("Missing EPUB package") }
        }
    }

    private static func runCalibre(input: URL, output: URL, calibre: String, root: URL) throws {
        let config = root.appendingPathComponent("calibre-fixture-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: config) }
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try ProcessRunner.run(.init(executable: "/usr/bin/env", arguments: ["CALIBRE_CONFIG_DIRECTORY=\(config.path)", "CALIBRE_TEMP_DIR=\(config.path)", calibre,
                                                                       input.path, output.path]), timeout: 120)
    }

    private static func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

private struct EbookFixtureError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
