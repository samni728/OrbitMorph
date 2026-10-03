import Foundation

public enum OutputNamer {
    public static func outputURL(
        for source: URL,
        target: FormatID,
        in directory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = target.fileExtension
        let direct = directory.appendingPathComponent(stem).appendingPathExtension(ext)
        if !fileManager.fileExists(atPath: direct.path) { return direct }

        let converted = directory.appendingPathComponent("\(stem)-converted").appendingPathExtension(ext)
        if !fileManager.fileExists(atPath: converted.path) { return converted }

        var index = 2
        while true {
            let candidate = directory.appendingPathComponent("\(stem)-converted-\(index)").appendingPathExtension(ext)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}
