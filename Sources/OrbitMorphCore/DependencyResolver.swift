import Foundation

public struct DependencyResolver: Sendable {
    private let resolved: [String: String]

    public init(overrides: [String: String?] = [:], fileManager: FileManager = .default) {
        let candidates: [String: [String]] = [
            "ffmpeg": ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"],
            "ffprobe": ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe"],
            "magick": ["/opt/homebrew/bin/magick", "/usr/local/bin/magick"],
            "pandoc": ["/opt/homebrew/bin/pandoc", "/usr/local/bin/pandoc"],
            "gs": ["/opt/homebrew/bin/gs", "/usr/local/bin/gs"],
            "7zz": ["/opt/homebrew/bin/7zz", "/usr/local/bin/7zz"],
            "textutil": ["/usr/bin/textutil"],
            "ditto": ["/usr/bin/ditto"],
            "tar": ["/usr/bin/tar"],
            "gzip": ["/usr/bin/gzip"]
        ]

        var output: [String: String] = [:]
        for (name, paths) in candidates {
            if overrides.keys.contains(name) {
                if let value = overrides[name] ?? nil { output[name] = value }
                continue
            }
            if let path = paths.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
                output[name] = path
            }
        }
        for (name, value) in overrides where candidates[name] == nil {
            if let value { output[name] = value }
        }
        self.resolved = output
    }

    public func path(for command: String) -> String? { resolved[command] }
    public func has(_ command: String) -> Bool { resolved[command] != nil }
    public var diagnostics: [String: String] { resolved }
}
