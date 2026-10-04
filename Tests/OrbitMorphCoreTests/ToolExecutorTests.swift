import XCTest
import PDFKit
@testable import OrbitMorphCore

final class ToolExecutorTests: XCTestCase {
    func testMergeCreatesNewOutputAndPreservesExistingPDF() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("a.pdf"), second = root.appendingPathComponent("b.pdf")
        for url in [first, second] {
            let doc = PDFDocument()
            let image = NSImage(size: NSSize(width: 40, height: 30))
            image.lockFocus(); NSColor.red.setFill(); NSRect(x: 0, y: 0, width: 40, height: 30).fill(); image.unlockFocus()
            doc.insert(try XCTUnwrap(PDFPage(image: image)), at: 0)
            XCTAssertTrue(doc.write(to: url))
        }
        let sentinel = root.appendingPathComponent("a-merged.pdf")
        try Data("keep existing".utf8).write(to: sentinel)
        let result = try ToolExecutor.perform(.pdfMerge, files: [first, second], dependencies: .init(), outputDirectory: root)
        let output = try XCTUnwrap(result.first)
        XCTAssertNotEqual(output, sentinel)
        XCTAssertEqual(try PDFDocument(url: XCTUnwrap(result.first))?.pageCount, 2)
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("keep existing".utf8))
    }

    func testBadPDFDoesNotProducePartialMerge() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("a.pdf"), second = root.appendingPathComponent("b.pdf")
        try Data("broken".utf8).write(to: first); try Data("broken".utf8).write(to: second)
        XCTAssertThrowsError(try ToolExecutor.perform(.pdfMerge, files: [first, second], dependencies: .init()))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), ["a.pdf", "b.pdf"])
    }

    func testUnsupportedDocumentToolFailsBeforeWriting() throws {
        let file = URL(fileURLWithPath: "/tmp/not-a-supported-tool.docx")
        XCTAssertThrowsError(try ToolExecutor.perform(.resizeImage, files: [file], dependencies: .init()))
    }
}
