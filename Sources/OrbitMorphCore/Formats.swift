import Foundation

public enum FileKind: String, Codable, CaseIterable, Sendable {
    case image, document, audio, video, archive, unknown
}

public enum FormatID: String, Codable, CaseIterable, Hashable, Sendable {
    case jpg, png, webp, heic, tiff, avif, bmp, gif, pdf
    case doc, docx, txt, md, rtf, html, odt
    case mp3, m4a, aac, wav, flac, ogg, opus, aiff
    case mp4, mov, mkv, webm, avi, m4v
    case zip, sevenZ = "7z", tar, tgz, gz, rar

    public init?(extension rawExtension: String) {
        let ext = rawExtension.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        switch ext {
        case "jpeg", "jpg", "jpe": self = .jpg
        case "png": self = .png
        case "webp": self = .webp
        case "heic", "heif": self = .heic
        case "tif", "tiff": self = .tiff
        case "avif": self = .avif
        case "bmp": self = .bmp
        case "gif": self = .gif
        case "pdf": self = .pdf
        case "doc": self = .doc
        case "docx": self = .docx
        case "txt", "text": self = .txt
        case "md", "markdown": self = .md
        case "rtf": self = .rtf
        case "html", "htm": self = .html
        case "odt": self = .odt
        case "mp3": self = .mp3
        case "m4a": self = .m4a
        case "aac": self = .aac
        case "wav", "wave": self = .wav
        case "flac": self = .flac
        case "ogg", "oga": self = .ogg
        case "opus": self = .opus
        case "aiff", "aif": self = .aiff
        case "mp4": self = .mp4
        case "mov", "qt": self = .mov
        case "mkv": self = .mkv
        case "webm": self = .webm
        case "avi": self = .avi
        case "m4v": self = .m4v
        case "zip": self = .zip
        case "7z": self = .sevenZ
        case "tar": self = .tar
        case "tgz", "tar.gz": self = .tgz
        case "gz", "gzip": self = .gz
        case "rar": self = .rar
        default: return nil
        }
    }

    public var fileExtension: String {
        switch self {
        case .sevenZ: return "7z"
        default: return rawValue
        }
    }

    public var kind: FileKind {
        switch self {
        case .jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif:
            return .image
        case .pdf, .doc, .docx, .txt, .md, .rtf, .html, .odt:
            return .document
        case .mp3, .m4a, .aac, .wav, .flac, .ogg, .opus, .aiff:
            return .audio
        case .mp4, .mov, .mkv, .webm, .avi, .m4v:
            return .video
        case .zip, .sevenZ, .tar, .tgz, .gz, .rar:
            return .archive
        }
    }
}
