import Foundation
import PDFKit
import XCTest
@testable import OrbitMorphCore

final class OfficeConversionTests: XCTestCase {
    func testAdapterConvertsRealODFToReadablePDF() throws {
        let dependencies = DependencyResolver()
        guard let path = dependencies.path(for: "soffice") else { throw XCTSkip("LibreOffice is not installed") }
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = try OfficeTestFixtures.makeODF(in: root, presentation: true)
        let output = root.appendingPathComponent("presentation.pdf")
        try LibreOfficeAdapter.convert(input: input, output: output, source: .odp, target: .pdf, sofficePath: path)
        try OfficeTestFixtures.validate(output: output, target: .pdf, root: root, dependencies: dependencies)
    }

    func testRealOfficeRoutesPreserveSheetsFormulaSlidesAndPDF() throws {
        let dependencies = DependencyResolver()
        guard let path = dependencies.path(for: "soffice") else { throw XCTSkip("LibreOffice is not installed") }
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = try OfficeTestFixtures.make(in: root, dependencies: dependencies)
        let output = root.appendingPathComponent("converted outputs 中文")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for source in [FormatID.xls, .xlsx, .ods, .ppt, .pptx, .odp] {
            let targets: [FormatID] = [.xls, .xlsx, .ods].contains(source) ? [.xls, .xlsx, .ods, .pdf] : [.ppt, .pptx, .odp, .pdf]
            for target in targets where target != source {
                let destination = output.appendingPathComponent("\(source.rawValue)-to-\(target.rawValue)").appendingPathExtension(target.fileExtension)
                let input = try XCTUnwrap(fixtures[source])
                let original = try Data(contentsOf: input)
                let siblings = Set(try FileManager.default.contentsOfDirectory(atPath: input.deletingLastPathComponent().path))
                try LibreOfficeAdapter.convert(input: input, output: destination, source: source, target: target, sofficePath: path)
                XCTAssertEqual(try Data(contentsOf: input), original)
                XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: input.deletingLastPathComponent().path)), siblings)
                try OfficeTestFixtures.validate(output: destination, target: target, root: root, dependencies: dependencies)
            }
        }
    }

    func testWriterDocumentsExportReadablePDF() throws {
        guard let path = DependencyResolver().path(for: "soffice") else { throw XCTSkip("LibreOffice is not installed") }
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let text = root.appendingPathComponent("memo.txt")
        try "OrbitMorph Writer PDF 中文".write(to: text, atomically: true, encoding: .utf8)
        for format in [FormatID.txt, .doc, .docx, .odt, .rtf, .html] {
            let input = format == .txt ? text : root.appendingPathComponent("memo").appendingPathExtension(format.fileExtension)
            if format != .txt {
                try ProcessRunner.run(.init(executable: "/usr/bin/textutil", arguments: ["-convert", format.fileExtension, "-output", input.path, text.path]))
            }
            let output = root.appendingPathComponent("writer-\(format.rawValue).pdf")
            try LibreOfficeAdapter.convert(input: input, output: output, source: format, target: .pdf, sofficePath: path)
            let pdf = try XCTUnwrap(PDFDocument(url: output))
            XCTAssertGreaterThan(pdf.pageCount, 0)
            XCTAssertTrue(pdf.string?.contains("OrbitMorph Writer PDF") == true)
        }
    }

    func testExistingOutputAndInputAreNeverOverwritten() throws {
        let dependencies = DependencyResolver()
        guard let path = dependencies.path(for: "soffice") else { throw XCTSkip("LibreOffice is not installed") }
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = try OfficeTestFixtures.makeODF(in: root, presentation: false)
        let inputData = try Data(contentsOf: input)
        let output = root.appendingPathComponent("existing.xlsx")
        try Data("sentinel".utf8).write(to: output)
        XCTAssertThrowsError(try LibreOfficeAdapter.convert(input: input, output: output, source: .ods, target: .xlsx, sofficePath: path))
        XCTAssertEqual(try Data(contentsOf: output), Data("sentinel".utf8))
        XCTAssertEqual(try Data(contentsOf: input), inputData)
        XCTAssertThrowsError(try LibreOfficeAdapter.convert(input: input, output: input, source: .ods, target: .xlsx, sofficePath: path))
        XCTAssertEqual(try Data(contentsOf: input), inputData)
    }

    func testRealDamagedInputFailsWithoutCreatingOutput() throws {
        guard let path = DependencyResolver().path(for: "soffice") else { throw XCTSkip("LibreOffice is not installed") }
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("damaged.xlsx")
        try Data([0, 1, 2, 3, 4]).write(to: input)
        let output = root.appendingPathComponent("damaged.pdf")
        XCTAssertThrowsError(try LibreOfficeAdapter.convert(input: input, output: output, source: .xlsx, target: .pdf, sofficePath: path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testTextMasqueradingAsXLSXIsRejectedInsteadOfExportingWriterPDF() throws {
        guard let path = DependencyResolver().path(for: "soffice") else { throw XCTSkip("LibreOffice is not installed") }
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("pretend.xlsx")
        try "This is ordinary text, not an Excel workbook.".write(to: input, atomically: true, encoding: .utf8)
        let output = root.appendingPathComponent("pretend.pdf")
        XCTAssertThrowsError(try LibreOfficeAdapter.convert(input: input, output: output, source: .xlsx, target: .pdf, sofficePath: path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testSymlinkInputLeavesOriginalFileAndDirectoryUntouched() throws {
        guard let path = DependencyResolver().path(for: "soffice") else { throw XCTSkip("LibreOffice is not installed") }
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try OfficeTestFixtures.makeODF(in: root, presentation: false)
        let originalData = try Data(contentsOf: original)
        let working = root.appendingPathComponent("symlink-conversion")
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
        let link = working.appendingPathComponent("shortcut.ods")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
        let before = Set(try FileManager.default.contentsOfDirectory(atPath: root.path))
        let output = working.appendingPathComponent("shortcut.xlsx")
        try LibreOfficeAdapter.convert(input: link, output: output, source: .ods, target: .xlsx, sofficePath: path)
        XCTAssertEqual(try Data(contentsOf: original), originalData)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)), before)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), original.path)
        try OfficeTestFixtures.validate(output: output, target: .xlsx, root: root, dependencies: DependencyResolver())
    }

    func testConversionsUseSeparateProfilesAndRemoveThem() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let log = root.appendingPathComponent("profiles.log")
        let executable = root.appendingPathComponent("profile-recorder")
        try "#!/bin/sh\nfor item do case \"$item\" in -env:UserInstallation=*) printf '%s\\n' \"${item#-env:UserInstallation=}\" >> \"$(dirname \"$0\")/profiles.log\";; esac; done\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let input = try OfficeTestFixtures.makeODF(in: root, presentation: false)
        for index in 0..<2 {
            XCTAssertThrowsError(try LibreOfficeAdapter.convert(input: input, output: root.appendingPathComponent("result-\(index).xlsx"), source: .ods, target: .xlsx, sofficePath: executable.path))
        }
        let profiles = try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map(String.init)
        XCTAssertEqual(Set(profiles).count, 2)
        for profile in profiles {
            let url = try XCTUnwrap(URL(string: profile))
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphOfficeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testSilentSuccessWithoutOutputFailsAndCleansWorkspace() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("silent-converter")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let input = try OfficeTestFixtures.makeODF(in: root, presentation: false)
        let original = try Data(contentsOf: input)
        let output = root.appendingPathComponent("result.xlsx")
        XCTAssertThrowsError(try LibreOfficeAdapter.convert(input: input, output: output, source: .ods, target: .xlsx, sofficePath: executable.path)) { error in
            guard case ConversionEngineError.outputMissing = error else { return XCTFail("Expected missing output, got \(error)") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)), ["silent-converter", input.lastPathComponent])
    }

    func testMalformedContainerFromSuccessfulConverterIsRejected() throws {
        let root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("invalid-converter")
        let body = "#!/bin/sh\nwhile [ $# -gt 0 ]; do\nif [ \"$1\" = --outdir ]; then shift; out=$1; fi\nshift\ndone\nprintf 'PK\\003\\004garbage' > \"$out/source.xlsx\"\n"
        try body.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let input = try OfficeTestFixtures.makeODF(in: root, presentation: false)
        let output = root.appendingPathComponent("output.xlsx")
        XCTAssertThrowsError(try LibreOfficeAdapter.convert(input: input, output: output, source: .ods, target: .xlsx, sofficePath: executable.path)) { error in
            guard case LibreOfficeAdapterError.invalidOutput = error else { return XCTFail("Expected invalid container, got \(error)") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }
}

enum OfficeTestFixtures {
    static func make(in root: URL, dependencies: DependencyResolver) throws -> [FormatID: URL] {
        guard let path = dependencies.path(for: "soffice") else { throw XCTSkip("LibreOffice is not installed") }
        let ods = try makeODF(in: root, presentation: false)
        let odp = try makeODF(in: root, presentation: true)
        var result: [FormatID: URL] = [.ods: ods, .odp: odp]
        for (input, targets) in [(ods, [FormatID.xls, .xlsx]), (odp, [FormatID.ppt, .pptx])] {
            for target in targets {
                let directory = root.appendingPathComponent("fixture-\(target.rawValue)")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try runLO(path: path, input: input, into: directory, filter: target.rawValue)
                let output = directory.appendingPathComponent(input.deletingPathExtension().lastPathComponent).appendingPathExtension(target.fileExtension)
                guard FileManager.default.fileExists(atPath: output.path) else { throw OfficeFixtureError("Fixture generation failed: \(target)") }
                result[target] = output
            }
        }
        return result
    }

    static func makeODF(in root: URL, presentation: Bool) throws -> URL {
        let folder = root.appendingPathComponent("odf-source-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let type = presentation ? "presentation" : "spreadsheet"
        let mime = "application/vnd.oasis.opendocument.\(type)"
        let namespaces = "xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" xmlns:table=\"urn:oasis:names:tc:opendocument:xmlns:table:1.0\" xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\" xmlns:draw=\"urn:oasis:names:tc:opendocument:xmlns:drawing:1.0\" xmlns:style=\"urn:oasis:names:tc:opendocument:xmlns:style:1.0\" xmlns:svg=\"urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0\" xmlns:fo=\"urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0\" xmlns:of=\"urn:oasis:names:tc:opendocument:xmlns:of:1.2\""
        let body: String
        if presentation {
            body = """
            <office:presentation><draw:page draw:name="Slide1" draw:master-page-name="Default"><draw:frame svg:x="1cm" svg:y="2cm" svg:width="23cm" svg:height="4cm"><draw:text-box><text:p>OrbitMorph Office first 第一页</text:p></draw:text-box></draw:frame></draw:page><draw:page draw:name="Slide2" draw:master-page-name="Default"><draw:frame svg:x="1cm" svg:y="2cm" svg:width="23cm" svg:height="4cm"><draw:text-box><text:p>OrbitMorph Office second 第二页</text:p></draw:text-box></draw:frame></draw:page></office:presentation>
            """
        } else {
            body = """
            <office:spreadsheet><table:table table:name="Sheet One"><table:table-row><table:table-cell office:value-type="string"><text:p>OrbitMorph Office first 数据</text:p></table:table-cell></table:table-row><table:table-row><table:table-cell office:value-type="float" office:value="7"><text:p>7</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="5"><text:p>5</text:p></table:table-cell><table:table-cell table:formula="of:=[.A2]+[.B2]" office:value-type="float" office:value="12"><text:p>12</text:p></table:table-cell></table:table-row></table:table><table:table table:name="Audit"><table:table-row><table:table-cell office:value-type="string"><text:p>OrbitMorph Office second 审计</text:p></table:table-cell></table:table-row></table:table></office:spreadsheet>
            """
        }
        let content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><office:document-content \(namespaces) office:version=\"1.2\"><office:automatic-styles/><office:body>\(body)</office:body></office:document-content>"
        let styles = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><office:document-styles \(namespaces) office:version=\"1.2\"><office:styles/><office:automatic-styles><style:page-layout style:name=\"PageLayout\"><style:page-layout-properties fo:page-width=\"28cm\" fo:page-height=\"21cm\" style:print-orientation=\"landscape\"/></style:page-layout></office:automatic-styles><office:master-styles><style:master-page style:name=\"Default\" style:page-layout-name=\"PageLayout\"/></office:master-styles></office:document-styles>"
        let manifest = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><manifest:manifest xmlns:manifest=\"urn:oasis:names:tc:opendocument:xmlns:manifest:1.0\" manifest:version=\"1.2\"><manifest:file-entry manifest:full-path=\"/\" manifest:media-type=\"\(mime)\"/><manifest:file-entry manifest:full-path=\"content.xml\" manifest:media-type=\"text/xml\"/><manifest:file-entry manifest:full-path=\"styles.xml\" manifest:media-type=\"text/xml\"/></manifest:manifest>"
        for (name, text) in [("mimetype", mime), ("content.xml", content), ("styles.xml", styles), ("META-INF/manifest.xml", manifest)] {
            try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let output = root.appendingPathComponent(presentation ? "Office 演示 空格.odp" : "Office 表格 空格.ods")
        try ProcessRunner.run(.init(executable: "/usr/bin/zip", arguments: ["-q", "-0", output.path, "mimetype"], workingDirectory: folder))
        try ProcessRunner.run(.init(executable: "/usr/bin/zip", arguments: ["-q", "-r", output.path, "content.xml", "styles.xml", "META-INF"], workingDirectory: folder))
        return output
    }

    static func validate(output: URL, target: FormatID, root: URL, dependencies: DependencyResolver) throws {
        let bytes = try Data(contentsOf: output)
        guard !bytes.isEmpty else { throw OfficeFixtureError("Empty Office output") }
        if target == .pdf {
            guard let pdf = PDFDocument(url: output), pdf.pageCount == 2 else { throw OfficeFixtureError("Office PDF must have two pages") }
            let first = pdf.page(at: 0)?.string ?? "", second = pdf.page(at: 1)?.string ?? ""
            guard first.contains("OrbitMorph Office first"), second.contains("OrbitMorph Office second") else { throw OfficeFixtureError("PDF text or page order lost") }
            return
        }
        let presentation = [.ppt, .pptx, .odp].contains(target)
        if target == .xls || target == .ppt {
            guard bytes.starts(with: [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]) else { throw OfficeFixtureError("Not an OLE Office document") }
        } else {
            try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-t", output.path]))
            let entries = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-Z1", output.path])).output.split(separator: "\n").map(String.init)
            let required = target == .xlsx ? "xl/workbook.xml" : target == .pptx ? "ppt/presentation.xml" : "content.xml"
            guard entries.contains(required) else { throw OfficeFixtureError("Missing Office XML: \(required)") }
        }
        guard let path = dependencies.path(for: "soffice") else { throw OfficeFixtureError("No LibreOffice for Office readback") }
        let check = root.appendingPathComponent("office-readback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: check, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: check) }
        let ext = presentation ? "fodp" : "fods"
        try runLO(path: path, input: output, into: check, filter: ext)
        let flat = check.appendingPathComponent(output.deletingPathExtension().lastPathComponent).appendingPathExtension(ext)
        let document = try XMLDocument(contentsOf: flat)
        if presentation {
            let pages = try document.nodes(forXPath: "//*[local-name()='presentation']/*[local-name()='page']")
            guard pages.count == 2, pages[0].stringValue?.contains("first 第一页") == true, pages[1].stringValue?.contains("second 第二页") == true else { throw OfficeFixtureError("Slide count, text or order lost") }
        } else {
            let tables = try document.nodes(forXPath: "//*[local-name()='spreadsheet']/*[local-name()='table']")
            guard tables.count == 2, tables[0].stringValue?.contains("first 数据") == true, tables[1].stringValue?.contains("second 审计") == true else { throw OfficeFixtureError("Sheets or Unicode text lost") }
            let cells = try tables[0].nodes(forXPath: "./*[local-name()='table-row'][2]/*[local-name()='table-cell']")
            guard cells.count >= 3 else { throw OfficeFixtureError("Missing numeric cells") }
            let values = try cells.prefix(3).map { try $0.nodes(forXPath: "./@*[local-name()='value']").first?.stringValue ?? "" }
            let formula = try cells[2].nodes(forXPath: "./@*[local-name()='formula']").first?.stringValue ?? ""
            guard values == ["7", "5", "12"], formula.contains("A2"), formula.contains("B2"), formula.contains("+") else { throw OfficeFixtureError("Numeric values or formula lost: \(values), \(formula)") }
        }
    }

    private static func runLO(path: String, input: URL, into directory: URL, filter: String) throws {
        let profile = directory.appendingPathComponent("profile-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: profile) }
        try ProcessRunner.run(.init(executable: path, arguments: ["-env:UserInstallation=\(profile.absoluteString)", "--headless", "--nologo", "--norestore", "--convert-to", filter, "--outdir", directory.path, input.path]), timeout: 120)
    }
}

private struct OfficeFixtureError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
