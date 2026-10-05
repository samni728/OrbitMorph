import Foundation
import PDFKit

public enum LibreOfficeAdapterError: LocalizedError {
    case invalidInput(URL)
    case invalidOutput(URL)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let url): return "Input does not contain a valid Office document: \(url.path)"
        case .invalidOutput(let url): return "LibreOffice produced an invalid or empty document: \(url.path)"
        }
    }
}

public enum LibreOfficeAdapter {
    public static func convert(input: URL, output: URL, source: FormatID, target: FormatID, sofficePath: String) throws {
        let filter = try exportFilter(source: source, target: target)
        let fm = FileManager.default
        guard !fm.fileExists(atPath: output.path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: [NSFilePathErrorKey: output.path])
        }
        let workspace = output.deletingLastPathComponent().appendingPathComponent(".OrbitMorph-office-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: workspace) }
        let inputs = workspace.appendingPathComponent("input", isDirectory: true)
        let outputs = workspace.appendingPathComponent("output", isDirectory: true)
        try fm.createDirectory(at: inputs, withIntermediateDirectories: false)
        try fm.createDirectory(at: outputs, withIntermediateDirectories: false)
        // LibreOffice may create lock files beside its input. Stage a private copy so
        // neither the source document nor its containing directory is modified.
        let staged = inputs.appendingPathComponent("source").appendingPathExtension(source.fileExtension)
        try fm.copyItem(at: input.resolvingSymlinksInPath(), to: staged)
        if [.xls, .xlsx, .ods, .ppt, .pptx, .odp].contains(source) {
            do { try validateStructure(staged, target: source) }
            catch { throw LibreOfficeAdapterError.invalidInput(input) }
        }
        let profile = workspace.appendingPathComponent("profile", isDirectory: true)
        try ProcessRunner.run(.init(executable: sofficePath, arguments: [
            "-env:UserInstallation=\(profile.absoluteString)",
            "--headless", "--nologo", "--nodefault", "--norestore",
            "--convert-to", "\(target.fileExtension):\(filter)",
            "--outdir", outputs.path, staged.path
        ]), timeout: 120)
        let generated = outputs.appendingPathComponent("source").appendingPathExtension(target.fileExtension)
        guard fm.fileExists(atPath: generated.path) else { throw ConversionEngineError.outputMissing(generated) }
        try validateStructure(generated, target: target)
        // moveItem fails if another caller created output while conversion ran.
        try fm.moveItem(at: generated, to: output)
    }

    private static func exportFilter(source: FormatID, target: FormatID) throws -> String {
        let spreadsheets: Set<FormatID> = [.xls, .xlsx, .ods]
        let presentations: Set<FormatID> = [.ppt, .pptx, .odp]
        let documents: Set<FormatID> = [.doc, .docx, .odt, .rtf, .html, .txt]
        if spreadsheets.contains(source), spreadsheets.contains(target) || target == .pdf {
            switch target {
            case .xls: return "MS Excel 97"
            case .xlsx: return "Calc MS Excel 2007 XML"
            case .ods: return "calc8"
            case .pdf: return "calc_pdf_Export"
            default: break
            }
        }
        if presentations.contains(source), presentations.contains(target) || target == .pdf {
            switch target {
            case .ppt: return "MS PowerPoint 97"
            case .pptx: return "Impress MS PowerPoint 2007 XML"
            case .odp: return "impress8"
            case .pdf: return "impress_pdf_Export"
            default: break
            }
        }
        if documents.contains(source), target == .pdf { return "writer_pdf_Export" }
        throw ConversionEngineError.unsupported(source, target)
    }

    private static func validateStructure(_ output: URL, target: FormatID) throws {
        let data = try Data(contentsOf: output)
        guard !data.isEmpty else { throw LibreOfficeAdapterError.invalidOutput(output) }
        if target == .pdf {
            guard let document = PDFDocument(url: output), document.pageCount > 0 else { throw LibreOfficeAdapterError.invalidOutput(output) }
            return
        }
        if target == .xls || target == .ppt {
            let streams = target == .xls ? ["Workbook", "Book"] : ["PowerPoint Document"]
            guard data.starts(with: [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]),
                  streams.contains(where: { stream in
                      guard let name = stream.data(using: .utf16LittleEndian) else { return false }
                      return data.range(of: name) != nil
                  }) else {
                throw LibreOfficeAdapterError.invalidOutput(output)
            }
            return
        }
        do {
            try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-t", output.path]), timeout: 30)
            let names = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-Z1", output.path]), timeout: 30).output.split(separator: "\n").map(String.init)
            let xmlName: String
            let root: String
            switch target {
            case .xlsx: xmlName = "xl/workbook.xml"; root = "workbook"
            case .pptx: xmlName = "ppt/presentation.xml"; root = "presentation"
            case .ods, .odp: xmlName = "content.xml"; root = "document-content"
            default: throw LibreOfficeAdapterError.invalidOutput(output)
            }
            guard names.contains(xmlName) else { throw LibreOfficeAdapterError.invalidOutput(output) }
            let xml = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, xmlName]), timeout: 30).output
            let parsed = try XMLDocument(xmlString: xml)
            guard parsed.rootElement()?.localName == root else { throw LibreOfficeAdapterError.invalidOutput(output) }
            if target == .ods || target == .odp {
                guard names.contains("META-INF/manifest.xml"), names.contains("mimetype") else { throw LibreOfficeAdapterError.invalidOutput(output) }
                let mime = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, "mimetype"]), timeout: 30).output
                let expected = target == .ods ? "application/vnd.oasis.opendocument.spreadsheet" : "application/vnd.oasis.opendocument.presentation"
                guard mime == expected,
                      !(try parsed.nodes(forXPath: "//*[local-name()='\(target == .ods ? "spreadsheet" : "presentation")']")).isEmpty else {
                    throw LibreOfficeAdapterError.invalidOutput(output)
                }
            } else {
                guard names.contains("[Content_Types].xml"), names.contains("_rels/.rels") else { throw LibreOfficeAdapterError.invalidOutput(output) }
                let typeXML = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, "\\[Content_Types\\].xml"]), timeout: 30).output
                let types = try XMLDocument(xmlString: typeXML)
                let expected = target == .xlsx ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml" : "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"
                guard !(try types.nodes(forXPath: "//*[local-name()='Override' and @ContentType='\(expected)']")).isEmpty else { throw LibreOfficeAdapterError.invalidOutput(output) }
            }
        } catch {
            throw LibreOfficeAdapterError.invalidOutput(output)
        }
    }
}
