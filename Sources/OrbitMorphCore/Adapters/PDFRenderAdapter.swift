import AppKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

public enum PDFRenderAdapter {
    public static func render(page: PDFPage, target: FormatID, output: URL, options: FormatDefaults = .init()) throws {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let width = max(1, Int(ceil(bounds.width * scale)))
        let height = max(1, Int(ceil(bounds.height * scale)))
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ConversionEngineError.pdfRenderFailed(output) }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else { throw ConversionEngineError.pdfRenderFailed(output) }
        let identifier = target == .jpg ? UTType.jpeg.identifier : UTType.png.identifier
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, identifier as CFString, 1, nil) else {
            throw ConversionEngineError.pdfRenderFailed(output)
        }
        var properties: [CFString: Any] = [:]
        if target == .jpg {
            properties[kCGImageDestinationLossyCompressionQuality] = min(1, max(0, options.quality ?? 0.92))
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ConversionEngineError.pdfRenderFailed(output) }
    }
}
