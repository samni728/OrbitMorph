import Foundation
import ImageIO
import PDFKit

/// Validate staged results before the engine publishes them under a user-visible name.
enum OutputValidation {
    static func validate(_ output: URL, target: FormatID, dependencies: DependencyResolver = .init()) throws {
        let attributes = try? FileManager.default.attributesOfItem(atPath: output.path)
        guard let attributes else { throw ConversionEngineError.outputMissing(output) }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.intValue ?? 0 > 0 else {
            throw ConversionEngineError.invalidOutput(output)
        }
        switch target {
        case .pdf:
            guard let document = PDFDocument(url: output), document.pageCount > 0 else {
                throw ConversionEngineError.invalidOutput(output)
            }
        case .docx:
            do {
                try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-tqq", output.path]))
                let document = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, "word/document.xml"])).output
                let contentTypes = try ProcessRunner.run(.init(executable: "/usr/bin/unzip", arguments: ["-p", output.path, "\\[Content_Types\\].xml"])).output
                guard document.contains("document"), contentTypes.contains("wordprocessingml") else {
                    throw ConversionEngineError.invalidOutput(output)
                }
            } catch {
                throw ConversionEngineError.invalidOutput(output)
            }
        default:
            do {
                if target.kind == .image {
                    try validateImage(output, dependencies: dependencies)
                } else if target.kind == .audio || target.kind == .video {
                    try validateMedia(output, target: target, dependencies: dependencies)
                }
            } catch { throw ConversionEngineError.invalidOutput(output) }
        }
    }

    private static func validateImage(_ output: URL, dependencies: DependencyResolver) throws {
        if let source = CGImageSourceCreateWithURL(output as CFURL, nil) {
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                           kCGImageSourceThumbnailMaxPixelSize: 64]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
               image.width > 0, image.height > 0 { return }
        }
        // JPEG XL and some JPEG 2000 builds need the installed ImageMagick delegate.
        guard let magick = dependencies.path(for: "magick") else { throw ConversionEngineError.invalidOutput(output) }
        let dimensions = try ProcessRunner.run(.init(executable: magick,
            arguments: [output.path + "[0]", "-resize", "64x64>", "-format", "%w %h", "info:"]), timeout: 60).output
        let values = dimensions.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
        guard values.count == 2, values.allSatisfy({ $0 > 0 }) else { throw ConversionEngineError.invalidOutput(output) }
    }

    private static func validateMedia(_ output: URL, target: FormatID, dependencies: DependencyResolver) throws {
        if let ffprobe = dependencies.path(for: "ffprobe") {
            struct Probe: Decodable { struct Stream: Decodable { let codec_type: String }; let streams: [Stream] }
            let json = try ProcessRunner.run(.init(executable: ffprobe,
                arguments: ["-v", "error", "-show_entries", "stream=codec_type", "-of", "json", output.path]), timeout: 30).output
            let probe = try JSONDecoder().decode(Probe.self, from: Data(json.utf8))
            let expected = target.kind == .video ? "video" : "audio"
            guard probe.streams.contains(where: { $0.codec_type == expected }) else { throw ConversionEngineError.invalidOutput(output) }
        } else if let ffmpeg = dependencies.path(for: "ffmpeg") {
            // Keep legacy ffmpeg-only installations usable with a short real decode.
            let stream = target.kind == .video ? "0:v:0" : "0:a:0"
            let progress = try ProcessRunner.run(.init(executable: ffmpeg,
                arguments: ["-hide_banner", "-v", "error", "-i", output.path, "-map", stream, "-t", "0.1", "-progress", "pipe:1", "-f", "null", "-"]), timeout: 30).output
            guard progress.components(separatedBy: .newlines).contains(where: {
                $0.hasPrefix("out_time_us=") && (Int($0.dropFirst("out_time_us=".count)) ?? 0) > 0
            }) else { throw ConversionEngineError.invalidOutput(output) }
        } else { throw ConversionEngineError.invalidOutput(output) }
    }
}
