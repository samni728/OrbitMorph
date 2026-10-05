import CoreText
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import XCTest
@testable import OrbitMorphCore

final class TextExtractionTests: XCTestCase {
    func testImageOCRProducesRecognizedEnglishAndChinese() throws {
        try withDirectory { root in
            let input = try TextTestFixtures.image(in: root, text: "OrbitMorph local OCR\n本地文字识别")
            let result = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .txt)).first)
            let text = try String(contentsOf: result.outputURL, encoding: .utf8)
            XCTAssertTrue(text.contains("OrbitMorph local OCR"), text)
            XCTAssertTrue(text.contains("本地文字识别"), text)
        }
    }

    func testSearchablePDFExtractsTextInPageOrderWithoutOCR() throws {
        try withDirectory { root in
            let input = try TextTestFixtures.pdf(in: root, pages: ["OrbitMorph page one", "OrbitMorph page two"])
            let result = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .txt)).first)
            let text = try String(contentsOf: result.outputURL, encoding: .utf8)
            XCTAssertTrue(text.contains("OrbitMorph page one\n\nOrbitMorph page two"), text)
        }
    }

    func testScannedPDFWithSearchableHeaderDoesNotLoseScannedBody() throws {
        try withDirectory { root in
            let imageURL = try TextTestFixtures.image(in: root, text: "OrbitMorph scanned body")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let input = root.appendingPathComponent("mixed.pdf")
            var box = CGRect(x: 0, y: 0, width: 900, height: 360)
            let context = try XCTUnwrap(CGContext(input as CFURL, mediaBox: &box, nil))
            context.beginPDFPage(nil)
            context.draw(image, in: CGRect(x: 0, y: 0, width: 900, height: 220))
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "OrbitMorph searchable header", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 32, nil)]))
            context.textPosition = CGPoint(x: 24, y: 300); CTLineDraw(line, context)
            context.endPDFPage(); context.closePDF()
            let result = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .txt)).first)
            let text = try String(contentsOf: result.outputURL, encoding: .utf8)
            XCTAssertTrue(text.contains("OrbitMorph searchable header"), text)
            XCTAssertTrue(text.contains("OrbitMorph scanned body"), text)
            XCTAssertEqual(text.components(separatedBy: "OrbitMorph searchable header").count - 1, 1, text)
        }
    }

    func testRotatedScannedPDFKeepsCompleteText() throws {
        try withDirectory { root in
            let imageURL = try TextTestFixtures.image(in: root, text: "OrbitMorph rotated scan")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let page = try XCTUnwrap(PDFPage(image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))))
            page.rotation = 90
            let document = PDFDocument(); document.insert(page, at: 0)
            let input = root.appendingPathComponent("rotated.pdf"); XCTAssertTrue(document.write(to: input))
            let result = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .txt)).first)
            XCTAssertTrue(try String(contentsOf: result.outputURL, encoding: .utf8).contains("OrbitMorph rotated scan"))
        }
    }

    func testScannedPDFOCRAndEditableDOCXContainText() throws {
        try withDirectory { root in
            let imageURL = try TextTestFixtures.image(in: root, text: "OrbitMorph scanned page")
            let image = try XCTUnwrap(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
            let cgImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(image, 0, nil))
            let doc = PDFDocument()
            doc.insert(try XCTUnwrap(PDFPage(image: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))), at: 0)
            let input = root.appendingPathComponent("扫描.pdf")
            XCTAssertTrue(doc.write(to: input))
            let result = try XCTUnwrap(ConversionEngine().convert(.init(inputs: [input], target: .docx)).first)
            let text = try ProcessRunner.run(.init(executable: "/usr/bin/textutil", arguments: ["-convert", "txt", "-stdout", result.outputURL.path])).output
            XCTAssertTrue(text.contains("OrbitMorph scanned page"), text)
        }
    }

    func testEmptyImageFailsWithoutCreatingAnEmptySuccessfulDocument() throws {
        try withDirectory { root in
            let input = try TextTestFixtures.image(in: root, text: "")
            XCTAssertThrowsError(try ConversionEngine().convert(.init(inputs: [input], target: .txt)))
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [input.lastPathComponent])
        }
    }

    func testBatchExtractionFailureRollsBackAndKeepsExistingOutput() throws {
        try withDirectory { root in
            let input = try TextTestFixtures.image(in: root, text: "OrbitMorph collision")
            let existing = root.appendingPathComponent("text-source.txt")
            try "existing".write(to: existing, atomically: true, encoding: .utf8)
            let bad = root.appendingPathComponent("broken.png")
            try Data("invalid".utf8).write(to: bad)
            XCTAssertThrowsError(try ConversionEngine().convert(.init(inputs: [input, bad], target: .txt)))
            XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "existing")
            XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)), Set([input.lastPathComponent, existing.lastPathComponent, bad.lastPathComponent]))
        }
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphText-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}

enum TextTestFixtures {
    static func image(in root: URL, text: String = "OrbitMorph matrix document") throws -> URL {
        let width = 900, height = 220
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        draw(text, in: context, height: CGFloat(height))
        let url = root.appendingPathComponent("text-source.png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    static func pdf(in root: URL, pages: [String]) throws -> URL {
        let url = root.appendingPathComponent("text-source.pdf")
        var box = CGRect(x: 0, y: 0, width: 900, height: 220)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for text in pages {
            context.beginPDFPage(nil); draw(text, in: context, height: 220); context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    private static func draw(_ text: String, in context: CGContext, height: CGFloat) {
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let font = CTFontCreateWithName("PingFangSC-Regular" as CFString, 38, nil)
            let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font,
                                                            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)]
            let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attributes))
            context.textPosition = CGPoint(x: 24, y: height - 65 - CGFloat(index) * 64)
            CTLineDraw(ctLine, context)
        }
    }
}
