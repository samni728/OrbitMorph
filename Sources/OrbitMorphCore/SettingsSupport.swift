import Foundation

public struct CompatibilityPolicy: Sendable {
    public let registry: ConversionRegistry
    public var disabledRoutes: Set<DisabledRoute>
    public init(registry: ConversionRegistry = ConversionRegistry(), disabledRoutes: Set<DisabledRoute>) {
        self.registry = registry; self.disabledRoutes = disabledRoutes
    }
    public func isSupported(source: FormatID, target: FormatID) -> Bool { registry.route(from: source, to: target) != nil }
    public func isEnabled(source: FormatID, target: FormatID) -> Bool {
        isSupported(source: source, target: target) && !disabledRoutes.contains(.init(source: source, target: target))
    }

    public func commonTargets(for files: [URL]) -> Set<FormatID> {
        let formats = files.compactMap { FormatID(fileURL: $0) }
        guard formats.count == files.count else { return [] }
        return registry.commonTargets(for: formats).filter { target in
            formats.allSatisfy { isEnabled(source: $0, target: target) }
        }
    }
}

public struct FolderRecord: Codable, Equatable, Sendable {
    public let category: FileKind
    public let displayPath: String
    public let bookmarkData: Data
    public init(category: FileKind, displayPath: String, bookmarkData: Data) {
        self.category = category; self.displayPath = displayPath; self.bookmarkData = bookmarkData
    }
}

public struct DependencyDiagnostic: Equatable, Sendable {
    public let name: String
    public let path: String?
    public var available: Bool { path != nil }

    public static func rows(resolver: DependencyResolver) -> [DependencyDiagnostic] {
        ["ffmpeg", "ffprobe", "magick", "pandoc", "soffice", "ebook-convert", "gs", "7zz", "textutil", "ditto", "tar", "gzip"].map {
            DependencyDiagnostic(name: $0, path: resolver.path(for: $0))
        }
    }
}

public enum FolderBookmarkStore {
    public static func makeRecord(category: FileKind, url: URL) throws -> FolderRecord {
        let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        return FolderRecord(category: category, displayPath: url.path, bookmarkData: data)
    }

    public static func resolve(_ record: FolderRecord) throws -> URL {
        var stale = false
        return try URL(resolvingBookmarkData: record.bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}
