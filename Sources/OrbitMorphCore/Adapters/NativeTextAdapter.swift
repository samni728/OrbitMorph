import Foundation
import ImageIO
import PDFKit
import Vision

public enum TextExtractionError: LocalizedError {
    case noText, lockedPDF, unreadableImage, unreadablePage
    public var errorDescription: String? {
        switch self {
        case .noText: return "No readable text found. OCR needs a clear image of printed text."
        case .lockedPDF: return "The PDF is password protected. Unlock a copy before extracting text."
        case .unreadableImage: return "Could not decode an image for text recognition."
        case .unreadablePage: return "Could not render a PDF page for text recognition."
        }
    }
}

/// Text extraction deliberately produces reading-order plain text, not a reconstruction of layout.
public enum NativeTextAdapter {
    public static func convert(input: URL, output: URL, source: FormatID, target: FormatID,
                               dependencies: DependencyResolver) throws {
        guard target == .txt || target == .docx else { throw ConversionEngineError.unsupportedTarget(target) }
        let text: String
        if source == .pdf {
            guard let document = PDFDocument(url: input) else { throw ConversionEngineError.emptyPDF(input) }
            guard !document.isLocked else { throw TextExtractionError.lockedPDF }
            guard document.pageCount > 0 else { throw ConversionEngineError.emptyPDF(input) }
            var pages: [String] = []
            for index in 0..<document.pageCount {
                let pageText = try autoreleasepool { () throws -> String in
                    guard let page = document.page(at: index) else { throw TextExtractionError.unreadablePage }
                    let layer = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let recognized = try recognize(render(page))
                    if layer.isEmpty { return recognized }
                    // Scans often have searchable headers/watermarks only. Keep the accurate
                    // existing layer, then add OCR lines it does not already contain.
                    let existing = normalized(layer)
                    let additions = recognized.components(separatedBy: .newlines).filter {
                        let line = normalized($0)
                        return !line.isEmpty && !existing.contains(line)
                    }
                    return ([layer] + additions).joined(separator: "\n")
                }
                pages.append(pageText)
            }
            text = pages.joined(separator: "\n\n")
        } else {
            text = try recognize(loadImage(input, dependencies: dependencies))
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TextExtractionError.noText }
        if target == .txt {
            try (text + "\n").write(to: output, atomically: true, encoding: .utf8)
        } else {
            guard let textutil = dependencies.path(for: "textutil") else { throw ConversionEngineError.missingDependency("textutil") }
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorph-Text-\(UUID().uuidString).txt")
            defer { try? FileManager.default.removeItem(at: temporary) }
            try (text + "\n").write(to: temporary, atomically: true, encoding: .utf8)
            try ProcessRunner.run(.init(executable: textutil, arguments: ["-convert", "docx", "-output", output.path, temporary.path]))
        }
    }

    private static func loadImage(_ input: URL, dependencies: DependencyResolver) throws -> CGImage {
        func decode(_ url: URL) -> CGImage? {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                           kCGImageSourceCreateThumbnailWithTransform: true,
                                           kCGImageSourceThumbnailMaxPixelSize: 3200]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        if let image = decode(input) { return image }
        guard let magick = dependencies.path(for: "magick") else { throw TextExtractionError.unreadableImage }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorph-OCR-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try ProcessRunner.run(.init(executable: magick, arguments: [input.path + "[0]", "-auto-orient", "-resize", "3200x3200>", temporary.path]))
        guard let image = decode(temporary) else { throw TextExtractionError.unreadableImage }
        return image
    }

    private static func render(_ page: PDFPage) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0, bounds.width.isFinite, bounds.height.isFinite else { throw TextExtractionError.unreadablePage }
        let scale = min(2, 3200 / max(bounds.width, bounds.height))
        let width = max(1, Int(ceil(bounds.width * scale))), height = max(1, Int(ceil(bounds.height * scale)))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw TextExtractionError.unreadablePage }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale); context.translateBy(x: -bounds.minX, y: -bounds.minY)
        // Draw unrotated page contents for recognition. PDFKit applies /Rotate while
        // keeping the original mediaBox dimensions, which clips 90/270-degree pages.
        guard let reference = page.pageRef else { throw TextExtractionError.unreadablePage }
        context.drawPDFPage(reference)
        guard let image = context.makeImage() else { throw TextExtractionError.unreadablePage }
        return image
    }

    private static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"].filter { supported.contains($0) }
        try VNImageRequestHandler(cgImage: image).perform([request])
        // Simple horizontal reading order. Complex columns and handwriting are not layout reconstruction.
        let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in observations {
            if let anchor = rows.last?.first, abs(anchor.boundingBox.midY - observation.boundingBox.midY) <= 0.015 {
                rows[rows.count - 1].append(observation)
            } else { rows.append([observation]) }
        }
        return rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        }.joined(separator: "\n")
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }
}
