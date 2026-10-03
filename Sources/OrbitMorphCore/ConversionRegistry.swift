import Foundation

public enum ConversionBackend: String, Codable, Sendable {
    case imageMagick, ffmpeg, pandoc, textutil, nativePDF, archive
}

public struct ConversionRoute: Hashable, Sendable {
    public let source: FormatID
    public let target: FormatID
    public let backend: ConversionBackend

    public init(source: FormatID, target: FormatID, backend: ConversionBackend) {
        self.source = source
        self.target = target
        self.backend = backend
    }
}

public struct ConversionRegistry: Sendable {
    public let dependencies: DependencyResolver

    public init(dependencies: DependencyResolver = DependencyResolver()) {
        self.dependencies = dependencies
    }

    public func targets(for source: FormatID) -> Set<FormatID> {
        Set(routes(for: source).map(\.target))
    }

    public func commonTargets(for sources: [FormatID]) -> Set<FormatID> {
        guard let first = sources.first else { return [] }
        return sources.dropFirst().reduce(targets(for: first)) { partial, source in
            partial.intersection(targets(for: source))
        }
    }

    public func route(from source: FormatID, to target: FormatID) -> ConversionRoute? {
        routes(for: source).first(where: { $0.target == target })
    }

    public func routes(for source: FormatID) -> [ConversionRoute] {
        var result: [ConversionRoute] = []

        if source.kind == .image, dependencies.has("magick") {
            let imageTargets: [FormatID] = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf]
            result += imageTargets.filter { $0 != source }.map { ConversionRoute(source: source, target: $0, backend: .imageMagick) }
        }

        if source.kind == .video || source.kind == .audio, dependencies.has("ffmpeg") {
            let mediaTargets: [FormatID]
            if source.kind == .video {
                mediaTargets = [.mp4, .mov, .mkv, .webm, .avi, .m4v, .gif, .mp3, .m4a, .wav, .flac, .ogg, .opus]
            } else {
                mediaTargets = [.mp3, .m4a, .aac, .wav, .flac, .ogg, .opus, .aiff]
            }
            result += mediaTargets.filter { $0 != source }.map { ConversionRoute(source: source, target: $0, backend: .ffmpeg) }
        }

        if source.kind == .document {
            if dependencies.has("pandoc") {
                let docTargets: [FormatID] = [.docx, .txt, .md, .rtf, .html, .odt]
                result += docTargets.filter { $0 != source }.map { ConversionRoute(source: source, target: $0, backend: .pandoc) }
            }
            if source == .pdf {
                result += [.jpg, .png].map { ConversionRoute(source: source, target: $0, backend: .nativePDF) }
            }
        }

        if source.kind == .archive {
            let archiveTargets: [FormatID] = [.zip, .sevenZ, .tar, .tgz]
            result += archiveTargets.filter { $0 != source }.map { ConversionRoute(source: source, target: $0, backend: .archive) }
        }

        return result
    }
}
