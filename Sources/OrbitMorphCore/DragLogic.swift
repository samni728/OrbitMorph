import Foundation

public enum GlobalDragEvent: Equatable, Sendable {
    case dragged(shift: Bool, option: Bool, sourceIsFinder: Bool)
    case modifiedDrag(mode: DragMode?, sourceHasFiles: Bool)
    case cancelled
    case filesResolved(count: Int)
    case mouseUp
    case dropCompleted
}

public struct FileDragPasteboardGate: Sendable {
    private var initialChangeCount: Int?
    public init() {}
    public mutating func begin(changeCount: Int) { initialChangeCount = changeCount }
    public mutating func end() { initialChangeCount = nil }
    public func accepts(changeCount: Int, validatedFileCount: Int) -> Bool {
        guard let initialChangeCount, validatedFileCount > 0 else { return false }
        return changeCount != initialChangeCount
    }
}

public enum GlobalDragPhase: Equatable, Sendable {
    case idle
    case armed(DragMode)
    case ready(DragMode)
}

public enum GlobalDragEffect: Equatable, Sendable {
    case none
    case show(DragMode)
    case filesReady
    case cancel
    case finish
}

public struct GlobalDragStateMachine: Sendable {
    public private(set) var phase: GlobalDragPhase = .idle
    public init() {}

    public mutating func handle(_ event: GlobalDragEvent) -> GlobalDragEffect {
        switch event {
        case let .dragged(shift, option, sourceIsFinder):
            return handle(.modifiedDrag(mode: ModifierMatcher.mode(shift: shift, option: option), sourceHasFiles: sourceIsFinder))
        case let .modifiedDrag(mode, sourceHasFiles):
            guard let mode else {
                guard phase != .idle else { return .none }
                phase = .idle
                return .cancel
            }
            switch phase {
            case .idle:
                guard sourceHasFiles else { return .none }
                phase = .armed(mode)
            case .armed(let previous):
                guard previous != mode else { return .none }
                phase = .armed(mode)
            case .ready(let previous):
                guard previous != mode else { return .none }
                phase = .ready(mode)
            }
            return .show(mode)
        case let .filesResolved(count):
            guard count > 0, case let .armed(mode) = phase else { return .none }
            phase = .ready(mode)
            return .filesReady
        case .mouseUp, .cancelled:
            guard phase != .idle else { return .none }
            phase = .idle
            return .cancel
        case .dropCompleted:
            guard case .ready = phase else { return .none }
            phase = .idle
            return .finish
        }
    }
}

public enum ToolActionID: String, CaseIterable, Codable, Hashable, Sendable {
    case compress
    case resizeImage
    case rotate
    case stripMetadata
    case extractAudio
    case makeGIF
    case pdfMerge
    case archive
    case unarchive

    public var label: String {
        switch self {
        case .compress: return "Compress"
        case .resizeImage: return "Resize"
        case .rotate: return "Rotate"
        case .stripMetadata: return "Clean"
        case .extractAudio: return "Audio"
        case .makeGIF: return "GIF"
        case .pdfMerge: return "Merge"
        case .archive: return "Archive"
        case .unarchive: return "Extract"
        }
    }
}

public enum ToolRegistry {
    public static func actions(for format: FormatID) -> Set<ToolActionID> {
        switch format.kind {
        case .image:
            if format == .svg { return [.archive] }
            return [.compress, .resizeImage, .rotate, .stripMetadata, .archive]
        case .video:
            return [.compress, .stripMetadata, .extractAudio, .makeGIF, .archive]
        case .audio:
            return [.compress, .stripMetadata, .archive]
        case .document:
            var values: Set<ToolActionID> = [.archive]
            if format == .pdf { values.insert(.pdfMerge) }
            return values
        case .subtitle:
            return [.archive]
        case .archive:
            return [.unarchive]
        case .unknown:
            return []
        }
    }

    public static func commonActions(for formats: [FormatID], dependencies: DependencyResolver = .init()) -> Set<ToolActionID> {
        guard let first = formats.first else { return [] }
        var result = formats.dropFirst().reduce(actions(for: first)) { $0.intersection(actions(for: $1)) }
        if formats.count < 2 { result.remove(.pdfMerge) }
        if !dependencies.has("ditto") { result.remove(.archive) }
        if !dependencies.has("7zz") {
            let canExtract = formats.allSatisfy { format in
                (format == .zip && dependencies.has("ditto")) ||
                ([.tar, .tgz].contains(format) && dependencies.has("tar"))
            }
            if !canExtract { result.remove(.unarchive) }
        }
        if formats.contains(where: { $0.kind == .image }), !dependencies.has("magick") {
            result.subtract([.resizeImage, .rotate, .stripMetadata, .compress])
        }
        if formats.contains(where: { $0.kind == .audio || $0.kind == .video }), !dependencies.has("ffmpeg") {
            result.subtract([.stripMetadata, .compress, .extractAudio, .makeGIF])
        }
        if let path = dependencies.path(for: "ffmpeg"),
           formats.contains(where: { ($0 == .wmv && !FFmpegAdapter.canEncodeWMV(ffmpegPath: path)) ||
               ($0 == .wma && !FFmpegAdapter.canEncodeWMA(ffmpegPath: path)) }) {
            result.remove(.compress)
        }
        return result
    }
}

public enum ValidatedFileURLs {
    public static func resolve(_ urls: [URL], fileManager: FileManager = .default) -> [URL] {
        urls.filter { url in
            url.isFileURL && fileManager.fileExists(atPath: url.path)
        }
    }
}
