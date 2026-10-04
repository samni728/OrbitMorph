import Foundation

public enum ConversionBackend: String, Codable, Sendable {
    case imageMagick, nativeImageIO, ffmpeg, pandoc, textutil, nativePDF, nativeSubtitle, archive
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

        if source.kind == .image, let magickPath = dependencies.path(for: "magick"),
           source != .svg || ImageMagickAdapter.canReadSVG(magickPath: magickPath) {
            let targets: [FormatID] = source == .svg
                ? [.png, .jpg, .webp, .pdf]
                : [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf]
            result += targets.filter { $0 != source }.map { .init(source: source, target: $0, backend: .imageMagick) }
        }

        if source.kind == .image, source != .svg, !dependencies.has("magick"), ImageIOAdapter.canRead(source) {
            let targets: [FormatID] = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf]
            result += targets.filter { $0 != source && ImageIOAdapter.canWrite($0) }
                .map { .init(source: source, target: $0, backend: .nativeImageIO) }
        }

        if source.kind == .video || source.kind == .audio, dependencies.has("ffmpeg") {
            var targets: [FormatID] = source.kind == .video
                ? [.mp4, .mov, .mkv, .webm, .avi, .m4v, .gif, .mp3, .m4a, .wav, .flac, .ogg, .opus]
                : [.mp3, .m4a, .aac, .wav, .flac, .ogg, .opus, .aiff]
            let ffmpegPath = dependencies.path(for: "ffmpeg")!
            let supportsVorbis = FFmpegAdapter.vorbisEncoder(ffmpegPath: ffmpegPath) != nil
            if source.kind == .video, FFmpegAdapter.canEncodeWMV(ffmpegPath: ffmpegPath) { targets.append(.wmv) }
            if source.kind == .audio, FFmpegAdapter.canEncodeWMA(ffmpegPath: ffmpegPath) { targets.append(.wma) }
            result += targets.filter { $0 != source && ($0 != .ogg || supportsVorbis) }
                .map { .init(source: source, target: $0, backend: .ffmpeg) }
        }

        if source.kind == .subtitle {
            let target: FormatID = source == .srt ? .vtt : .srt
            result.append(.init(source: source, target: target, backend: .nativeSubtitle))
        }

        if source == .pdf {
            result += [FormatID.jpg, .png].map { .init(source: source, target: $0, backend: .nativePDF) }
        } else if source.kind == .document {
            let pandocReaders: Set<FormatID> = [.md, .html, .docx, .odt, .rtf]
            let pandocWriters: [FormatID] = [.docx, .txt, .md, .rtf, .html, .odt]
            if dependencies.has("pandoc"), pandocReaders.contains(source) {
                result += pandocWriters.filter { $0 != source }.map { .init(source: source, target: $0, backend: .pandoc) }
            }
            let textutilReaders: Set<FormatID> = [.txt, .rtf, .html, .doc, .docx, .odt]
            let textutilWriters: [FormatID] = [.txt, .rtf, .html, .doc, .docx, .odt]
            if dependencies.has("textutil"), textutilReaders.contains(source) {
                let existing = Set(result.map(\.target))
                result += textutilWriters.filter { $0 != source && !existing.contains($0) }
                    .map { .init(source: source, target: $0, backend: .textutil) }
            }
        }

        if source.kind == .archive {
            let sevenZip = dependencies.has("7zz")
            let canExtract: Bool
            switch source {
            case .zip: canExtract = sevenZip || dependencies.has("ditto")
            case .tar, .tgz: canExtract = sevenZip || dependencies.has("tar")
            default: canExtract = sevenZip
            }
            if canExtract {
                var targets: [FormatID] = []
                if sevenZip || dependencies.has("ditto") { targets.append(.zip) }
                if sevenZip { targets.append(.sevenZ) }
                if sevenZip || dependencies.has("tar") { targets += [.tar, .tgz] }
                result += targets.filter { $0 != source }.map { .init(source: source, target: $0, backend: .archive) }
            }
        }
        return result
    }
}
