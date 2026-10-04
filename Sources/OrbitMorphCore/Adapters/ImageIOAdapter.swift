import AppKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

public enum ImageIOAdapter {
    private static func typeIdentifier(for format: FormatID) -> String? {
        UTType(filenameExtension: format.fileExtension)?.identifier
    }

    public static func canRead(_ format: FormatID) -> Bool {
        guard let identifier = typeIdentifier(for: format) else { return false }
        return (CGImageSourceCopyTypeIdentifiers() as NSArray as? [String] ?? []).contains(identifier)
    }

    public static func canWrite(_ format: FormatID) -> Bool {
        if format == .pdf { return true }
        guard let identifier = typeIdentifier(for: format) else { return false }
        return (CGImageDestinationCopyTypeIdentifiers() as NSArray as? [String] ?? []).contains(identifier)
    }

    public static func convert(input: URL, output: URL, target: FormatID, options: FormatDefaults = .init()) throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ConversionEngineError.imageDecodeFailed(input)
        }
        if target == .pdf {
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            guard let page = PDFPage(image: nsImage) else { throw ConversionEngineError.imageDecodeFailed(input) }
            let document = PDFDocument()
            document.insert(page, at: 0)
            guard document.write(to: output) else { throw ConversionEngineError.outputMissing(output) }
            return
        }
        guard let identifier = typeIdentifier(for: target),
              let destination = CGImageDestinationCreateWithURL(output as CFURL, identifier as CFString, 1, nil) else {
            throw ConversionEngineError.unsupportedTarget(target)
        }
        var properties = options.preserveMetadata
            ? (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:])
            : [:]
        if let quality = options.quality {
            properties[kCGImageDestinationLossyCompressionQuality] = min(1, max(0, quality))
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConversionEngineError.outputMissing(output) }
    }
}
