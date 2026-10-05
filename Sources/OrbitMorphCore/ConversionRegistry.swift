import Foundation

public enum ConversionBackend: String, Codable, Sendable {
    case imageMagick, nativeImageIO, ffmpeg, pandoc, textutil, nativePDF, nativeSubtitle, nativeText, libreOffice, calibre, archive
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

        let extendedImages: Set<FormatID> = [.ico, .jp2, .jxl, .psd]
        if source.kind == .image, let magickPath = dependencies.path(for: "magick"),
           (source != .svg || ImageMagickAdapter.canReadSVG(magickPath: magickPath)),
           (!extendedImages.contains(source) || ImageMagickAdapter.canRoundTrip(source, magickPath: magickPath)) {
            var targets: [FormatID] = source == .svg
                ? [.png, .jpg, .webp, .pdf]
                : [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf]
            if source != .svg {
                targets += [FormatID.ico, .jp2, .jxl].filter { ImageMagickAdapter.canRoundTrip($0, magickPath: magickPath) }
            }
            result += targets.filter { $0 != source }.map { .init(source: source, target: $0, backend: .imageMagick) }
        }

        if source.kind == .image, source != .svg, !dependencies.has("magick"), ImageIOAdapter.canRead(source) {
            let targets: [FormatID] = [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf]
            result += targets.filter { $0 != source && ImageIOAdapter.canWrite($0) }
                .map { .init(source: source, target: $0, backend: .nativeImageIO) }
        }

        if source.kind == .video || source.kind == .audio, dependencies.has("ffmpeg") {
            var targets: [FormatID] = source.kind == .video
                ? [.mp4, .mov, .mkv, .webm, .avi, .m4v, .gif, .mp3, .m4a, .aac, .wav, .flac, .ogg, .opus, .aiff]
                : [.mp3, .m4a, .aac, .wav, .flac, .ogg, .opus, .aiff]
            let ffmpegPath = dependencies.path(for: "ffmpeg")!
            let supportsVorbis = FFmpegAdapter.vorbisEncoder(ffmpegPath: ffmpegPath) != nil
            if source.kind == .video, FFmpegAdapter.canEncodeWMV(ffmpegPath: ffmpegPath, ffprobePath: dependencies.path(for: "ffprobe")) { targets.append(.wmv) }
            if FFmpegAdapter.canEncodeWMA(ffmpegPath: ffmpegPath, ffprobePath: dependencies.path(for: "ffprobe")) { targets.append(.wma) }
            if FFmpegAdapter.canEncodeExtended(.caf, ffmpegPath: ffmpegPath, ffprobePath: dependencies.path(for: "ffprobe")) { targets.append(.caf) }
            if source.kind == .video {
                targets += [FormatID.flv, .ts, .threeGP].filter { FFmpegAdapter.canEncodeExtended($0, ffmpegPath: ffmpegPath, ffprobePath: dependencies.path(for: "ffprobe")) }
            }
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

        let ocrImages: Set<FormatID> = [.jpg, .png, .tiff, .bmp, .heic, .webp, .avif]
        if source == .pdf || (ocrImages.contains(source) && (ImageIOAdapter.canRead(source) || dependencies.has("magick"))) {
            var targets: [FormatID] = [.txt]
            if dependencies.has("textutil") { targets.append(.docx) }
            result += targets.map { .init(source: source, target: $0, backend: .nativeText) }
        }

        if dependencies.has("soffice") {
            let targets: [FormatID]
            switch source.kind {
            case .spreadsheet: targets = [.xls, .xlsx, .ods, .pdf]
            case .presentation: targets = [.ppt, .pptx, .odp, .pdf]
            case .document where [.doc, .docx, .odt, .rtf, .html, .txt].contains(source): targets = [.pdf]
            default: targets = []
            }
            result += targets.filter { $0 != source }.map { .init(source: source, target: $0, backend: .libreOffice) }
        }

        if dependencies.has("ebook-convert") {
            var targets: [FormatID] = []
            if source.kind == .ebook {
                targets = [.epub, .mobi, .azw3, .txt, .docx, .pdf]
            } else if [.txt, .html, .docx].contains(source) {
                targets = [.epub, .mobi, .azw3]
            }
            result += targets.filter { $0 != source }.map { .init(source: source, target: $0, backend: .calibre) }
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
