import Foundation
import PDFKit

public enum CalibreAdapter {
    public static func convert(input: URL, output: URL, source: FormatID, target: FormatID, ebookConvertPath: String) throws {
        let books: Set<FormatID> = [.epub, .mobi, .azw3]
        let supported = (books.contains(source) && (books.contains(target) || [.txt, .docx, .pdf].contains(target))) ||
            ([FormatID.txt, .html, .docx].contains(source) && books.contains(target))
        guard supported, source != target else { throw ConversionEngineError.unsupported(source, target) }
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: ebookConvertPath) else { throw ConversionEngineError.missingDependency("ebook-convert") }
        let input = input.standardizedFileURL
        let output = output.standardizedFileURL
        guard input != output, !fm.fileExists(atPath: output.path) else { throw CalibreConversionError.outputAlreadyExists(output) }
        let work = fm.temporaryDirectory.appendingPathComponent("OrbitMorph-Calibre-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let config = work.appendingPathComponent("config")
        let temporary = work.appendingPathComponent("converted.\(target.fileExtension)")
        // Calibre normally creates user preferences on its first invocation. Keep those,
        // its worker scratch files and the staged result inside this conversion's directory.
        var args = ["CALIBRE_CONFIG_DIRECTORY=\(config.path)", "CALIBRE_TEMP_DIR=\(work.path)",
                    URL(fileURLWithPath: ebookConvertPath).standardizedFileURL.path, input.path, temporary.path]
        if target == .pdf {
            args.insert(contentsOf: ["QT_QPA_PLATFORM=offscreen", "QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu"], at: 0)
            args += ["--pdf-serif-family", "Songti SC", "--pdf-sans-family", "PingFang SC"]
        }
        try ProcessRunner.run(.init(executable: "/usr/bin/env", arguments: args, workingDirectory: work))
        try validate(temporary, target: target)
        // The engine supplies a fresh temporary output. copyItem also refuses to replace
        // an existing destination if another process creates it after the earlier check.
        try fm.copyItem(at: temporary, to: output)
    }

    private static func validate(_ output: URL, target: FormatID) throws {
        let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 else { throw ConversionEngineError.outputMissing(output) }
        switch target {
        case .epub, .docx:
            try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-tqq", output.path]))
            if target == .epub {
                let mime = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, "mimetype"])).output
                let container = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, "META-INF/container.xml"])).output
                guard mime == "application/epub+zip", container.contains("rootfile") else { throw CalibreConversionError.invalidOutput(target) }
            } else {
                let document = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, "word/document.xml"])).output
                guard document.contains("document") else { throw CalibreConversionError.invalidOutput(target) }
            }
        case .mobi, .azw3:
            let handle = try FileHandle(forReadingFrom: output)
            defer { try? handle.close() }
            let header = try handle.read(upToCount: 78) ?? Data()
            guard header.count == 78, String(data: header.subdata(in: 60..<68), encoding: .ascii) == "BOOKMOBI" else {
                throw CalibreConversionError.invalidOutput(target)
            }
            let recordCount = Int(header[76]) << 8 | Int(header[77])
            guard recordCount >= 2, 78 + recordCount * 8 < size else { throw CalibreConversionError.invalidOutput(target) }
            let firstEntry = try handle.read(upToCount: 8) ?? Data()
            guard firstEntry.count == 8 else { throw CalibreConversionError.invalidOutput(target) }
            let firstOffset = firstEntry.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            guard firstOffset >= 78 + recordCount * 8, firstOffset + 44 <= size else { throw CalibreConversionError.invalidOutput(target) }
            try handle.seek(toOffset: UInt64(firstOffset))
            let recordHeader = try handle.read(upToCount: 44) ?? Data()
            let compression = recordHeader.prefix(2).reduce(0) { ($0 << 8) | Int($1) }
            let textLength = recordHeader.dropFirst(4).prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            let textRecords = recordHeader.dropFirst(8).prefix(2).reduce(0) { ($0 << 8) | Int($1) }
            let mobiLength = recordHeader.dropFirst(20).prefix(4).reduce(0) { ($0 << 8) | Int($1) }
            guard recordHeader.count == 44, [1, 2, 17480].contains(compression),
                  textLength > 0, textRecords > 0, textRecords < recordCount,
                  mobiLength >= 28, firstOffset + 16 + mobiLength <= size,
                  String(data: recordHeader.subdata(in: 16..<20), encoding: .ascii) == "MOBI" else {
                throw CalibreConversionError.invalidOutput(target)
            }
        case .txt:
            let text = try String(contentsOf: output, encoding: .utf8)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CalibreConversionError.invalidOutput(target) }
        case .pdf:
            guard let pdf = PDFDocument(url: output), pdf.pageCount > 0 else { throw CalibreConversionError.invalidOutput(target) }
        default:
            throw ConversionEngineError.unsupportedTarget(target)
        }
    }
}

private enum CalibreConversionError: LocalizedError {
    case outputAlreadyExists(URL)
    case invalidOutput(FormatID)

    var errorDescription: String? {
        switch self {
        case .outputAlreadyExists(let url): return "Ebook conversion refuses to overwrite: \(url.path)"
        case .invalidOutput(let format): return "Calibre produced an invalid \(format.rawValue.uppercased()) file"
        }
    }
}
