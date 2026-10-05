import Foundation

public enum FileKind: String, Codable, CaseIterable, Sendable {
    case image, document, spreadsheet, presentation, ebook, audio, video, subtitle, archive, unknown
}

public enum FormatID: String, Codable, CaseIterable, Hashable, Sendable {
    case jpg, png, webp, heic, tiff, avif, bmp, gif, pdf, svg
    case doc, docx, txt, md, rtf, html, odt
    case xls, xlsx, ods, ppt, pptx, odp, epub, mobi, azw3
    case ico, jp2, jxl, psd
    case mp3, m4a, aac, wav, flac, ogg, opus, aiff, wma
    case mp4, mov, mkv, webm, avi, m4v, wmv
    case flv, ts, threeGP = "3gp", caf
    case srt, vtt
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
        case "svg": self = .svg
        case "doc": self = .doc
        case "docx": self = .docx
        case "txt", "text": self = .txt
        case "md", "markdown": self = .md
        case "rtf": self = .rtf
        case "html", "htm": self = .html
        case "odt": self = .odt
        case "xls": self = .xls
        case "xlsx": self = .xlsx
        case "ods": self = .ods
        case "ppt": self = .ppt
        case "pptx": self = .pptx
        case "odp": self = .odp
        case "epub": self = .epub
        case "mobi": self = .mobi
        case "azw3": self = .azw3
        case "ico": self = .ico
        case "jp2", "j2k", "jpf", "jpx": self = .jp2
        case "jxl": self = .jxl
        case "psd": self = .psd
        case "mp3": self = .mp3
        case "m4a": self = .m4a
        case "aac": self = .aac
        case "wav", "wave": self = .wav
        case "flac": self = .flac
        case "ogg", "oga": self = .ogg
        case "opus": self = .opus
        case "aiff", "aif": self = .aiff
        case "wma": self = .wma
        case "mp4": self = .mp4
        case "mov", "qt": self = .mov
        case "mkv": self = .mkv
        case "webm": self = .webm
        case "avi": self = .avi
        case "m4v": self = .m4v
        case "wmv": self = .wmv
        case "flv": self = .flv
        case "ts", "mts", "m2ts": self = .ts
        case "3gp", "3gpp": self = .threeGP
        case "caf": self = .caf
        case "srt": self = .srt
        case "vtt": self = .vtt
        case "zip": self = .zip
        case "7z": self = .sevenZ
        case "tar": self = .tar
        case "tgz", "tar.gz": self = .tgz
        case "gz", "gzip": self = .gz
        case "rar": self = .rar
        default: return nil
        }
    }

    public init?(fileURL: URL) {
        if fileURL.lastPathComponent.lowercased().hasSuffix(".tar.gz") {
            self = .tgz
        } else {
            self.init(extension: fileURL.pathExtension)
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
        case .jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .svg, .ico, .jp2, .jxl, .psd:
            return .image
        case .pdf, .doc, .docx, .txt, .md, .rtf, .html, .odt:
            return .document
        case .xls, .xlsx, .ods: return .spreadsheet
        case .ppt, .pptx, .odp: return .presentation
        case .epub, .mobi, .azw3: return .ebook
        case .mp3, .m4a, .aac, .wav, .flac, .ogg, .opus, .aiff, .wma, .caf:
            return .audio
        case .mp4, .mov, .mkv, .webm, .avi, .m4v, .wmv, .flv, .ts, .threeGP:
            return .video
        case .srt, .vtt:
            return .subtitle
        case .zip, .sevenZ, .tar, .tgz, .gz, .rar:
            return .archive
        }
    }
}
