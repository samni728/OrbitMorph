import Foundation

public enum ArchiveAdapter {
    public static func convert(input: URL, output: URL, target: FormatID, dependencies: DependencyResolver) throws {
        guard let sevenZip = dependencies.path(for: "7zz") else {
            throw ConversionEngineError.missingDependency("7zz")
        }
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("OrbitMorphArchive-\(UUID().uuidString)")
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }

        try ProcessRunner.run(.init(executable: sevenZip, arguments: ["x", "-y", "-o\(temp.path)", input.path]))
        switch target {
        case .sevenZ:
            try ProcessRunner.run(.init(executable: sevenZip, arguments: ["a", "-t7z", output.path, temp.path]))
        case .zip:
            try ProcessRunner.run(.init(executable: sevenZip, arguments: ["a", "-tzip", output.path, temp.path]))
        case .tar:
            try ProcessRunner.run(.init(executable: sevenZip, arguments: ["a", "-ttar", output.path, temp.path]))
        case .tgz:
            let tarURL = output.deletingPathExtension().appendingPathExtension("tar")
            defer { try? fm.removeItem(at: tarURL) }
            try ProcessRunner.run(.init(executable: sevenZip, arguments: ["a", "-ttar", tarURL.path, temp.path]))
            try ProcessRunner.run(.init(executable: sevenZip, arguments: ["a", "-tgzip", output.path, tarURL.path]))
        default:
            throw ConversionEngineError.unsupportedTarget(target)
        }
    }
}
