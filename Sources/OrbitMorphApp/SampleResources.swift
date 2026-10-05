import Foundation

enum SampleResources {
    private static let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorph-Tutorial-\(UUID().uuidString)")
    static var imageURL: URL { writableSample("OrbitMorph-Sample", ext: "png") }
    static var videoURL: URL { writableSample("OrbitMorph-Sample-Video", ext: "mp4") }
    static var tickSoundURL: URL { locate("segment-tick", ext: "wav", subdirectory: "Sounds") }

    static func prepareSample(source: URL, in directory: URL) throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { throw CocoaError(.fileReadNoSuchFile) }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        guard source.standardizedFileURL != destination.standardizedFileURL else { throw CocoaError(.fileWriteFileExists) }
        if fm.fileExists(atPath: destination.path) {
            guard try Data(contentsOf: source) == Data(contentsOf: destination) else { throw CocoaError(.fileWriteFileExists) }
        } else { try fm.copyItem(at: source, to: destination) }
        return destination
    }

    private static func writableSample(_ name: String, ext: String) -> URL {
        do { return try prepareSample(source: locate(name, ext: ext, subdirectory: "Samples"), in: workspace) }
        catch {
            print("ORBITMORPH tutorial-sample=unavailable error=\(error.localizedDescription)")
            // Keep a missing URL in the writable workspace so dragging cannot mutate a bundle.
            return workspace.appendingPathComponent("\(name).\(ext)")
        }
    }

    private static func locate(_ name: String, ext: String, subdirectory: String) -> URL {
        if let bundled = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return bundled
        }
        let development = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/\(subdirectory)/\(name).\(ext)")
        if FileManager.default.fileExists(atPath: development.path) { return development }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent(subdirectory, isDirectory: true)
            .appendingPathComponent("\(name).\(ext)")
    }
}
