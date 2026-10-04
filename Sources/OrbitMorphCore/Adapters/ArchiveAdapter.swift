import Foundation

public enum ArchiveAdapter {
    public static func extract(input: URL, into directory: URL, dependencies: DependencyResolver) throws {
        let source = FormatID(fileURL: input)
        let sevenZip = dependencies.path(for: "7zz")
        let listing: String
        if source == .zip {
            listing = try ProcessRunner.run(.init(executable: "/usr/bin/zipinfo", arguments: ["-1", input.path])).output
            let verbose = try ProcessRunner.run(.init(executable: "/usr/bin/zipinfo", arguments: ["-l", input.path])).output
            try rejectLinks(in: verbose)
        } else if source == .tar || source == .tgz, let tar = dependencies.path(for: "tar") {
            listing = try ProcessRunner.run(.init(executable: tar, arguments: ["-tf", input.path])).output
            let verbose = try ProcessRunner.run(.init(executable: tar, arguments: ["-tvf", input.path])).output
            try rejectLinks(in: verbose)
        } else {
            guard let sevenZip else { throw ConversionEngineError.missingDependency("7zz") }
            let detail = try ProcessRunner.run(.init(executable: sevenZip, arguments: ["l", "-slt", input.path])).output
            try rejectLinks(in: detail)
            listing = detail.components(separatedBy: "----------").dropFirst().joined(separator: "----------")
                .components(separatedBy: .newlines)
                .filter { $0.hasPrefix("Path = ") }
                .map { String($0.dropFirst("Path = ".count)) }
                .joined(separator: "\n")
        }
        for entry in listing.components(separatedBy: .newlines) where !entry.isEmpty {
            let normalized = entry.replacingOccurrences(of: "\\", with: "/")
            let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
            if normalized.hasPrefix("/") || parts.contains("..") || normalized.hasPrefix("~") {
                throw ConversionEngineError.unsafeArchiveEntry(entry)
            }
        }

        let existedBefore = FileManager.default.fileExists(atPath: directory.path)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let sevenZip {
            try ProcessRunner.run(.init(executable: sevenZip, arguments: ["x", "-y", "-o\(directory.path)", input.path]))
            if source == .tgz,
               let tarFile = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "tar" }) {
                try extract(input: tarFile, into: directory, dependencies: dependencies)
                try FileManager.default.removeItem(at: tarFile)
            }
        } else {
            switch source {
            case .zip:
                guard let ditto = dependencies.path(for: "ditto") else { throw ConversionEngineError.missingDependency("ditto") }
                try ProcessRunner.run(.init(executable: ditto, arguments: ["-x", "-k", input.path, directory.path]))
            case .tar, .tgz:
                guard let tar = dependencies.path(for: "tar") else { throw ConversionEngineError.missingDependency("tar") }
                try ProcessRunner.run(.init(executable: tar, arguments: [source == .tgz ? "-xzf" : "-xf", input.path, "-C", directory.path]))
            default:
                throw ConversionEngineError.missingDependency("7zz")
            }
        }
        } catch {
            if !existedBefore { try? FileManager.default.removeItem(at: directory) }
            throw error
        }
    }

    private static func rejectLinks(in listing: String) throws {
        for line in listing.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let mode = trimmed.split(whereSeparator: \.isWhitespace).first(where: { token in
                token.count == 10 && (token.first == "l" || token.first == "h")
            })
            if mode != nil || trimmed.hasPrefix("Hard Link = ") || trimmed.hasPrefix("Symbolic Link = ") {
                throw ConversionEngineError.unsafeArchiveEntry(trimmed)
            }
        }
    }

    public static func convert(
        input: URL,
        output: URL,
        target: FormatID,
        dependencies: DependencyResolver,
        options: FormatDefaults = .init()
    ) throws {
        let fm = FileManager.default
        let extracted = fm.temporaryDirectory.appendingPathComponent("OrbitMorphArchive-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: extracted) }
        try extract(input: input, into: extracted, dependencies: dependencies)

        if target == .sevenZ || (dependencies.path(for: "7zz") != nil && target == .zip) {
            guard let sevenZip = dependencies.path(for: "7zz") else { throw ConversionEngineError.missingDependency("7zz") }
            let type = target == .sevenZ ? "7z" : "zip"
            var args = ["a", "-t\(type)"]
            if let level = options.archiveLevel { args.append("-mx=\(max(0, min(9, level)))") }
            args += [output.path, "."]
            try ProcessRunner.run(.init(executable: sevenZip, arguments: args, workingDirectory: extracted))
            return
        }
        switch target {
        case .zip:
            guard let ditto = dependencies.path(for: "ditto") else { throw ConversionEngineError.missingDependency("ditto") }
            try ProcessRunner.run(.init(executable: ditto, arguments: ["-c", "-k", "--sequesterRsrc", extracted.path, output.path]))
        case .tar, .tgz:
            guard let tar = dependencies.path(for: "tar") else { throw ConversionEngineError.missingDependency("tar") }
            try ProcessRunner.run(.init(executable: tar, arguments: [target == .tgz ? "-czf" : "-cf", output.path, "-C", extracted.path, "."]))
        default:
            throw ConversionEngineError.unsupportedTarget(target)
        }
    }
}
