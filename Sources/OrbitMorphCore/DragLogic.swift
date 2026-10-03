import Foundation

public enum GlobalDragEvent: Equatable, Sendable {
    case dragged(shift: Bool, option: Bool, sourceIsFinder: Bool)
    case filesResolved(count: Int)
    case mouseUp
    case dropCompleted
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
            guard case .idle = phase, sourceIsFinder, let mode = ModifierMatcher.mode(shift: shift, option: option) else { return .none }
            phase = .armed(mode)
            return .show(mode)
        case let .filesResolved(count):
            guard count > 0, case let .armed(mode) = phase else { return .none }
            phase = .ready(mode)
            return .filesReady
        case .mouseUp:
            if case .armed = phase {
                phase = .idle
                return .cancel
            }
            return .none
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
            return [.compress, .resizeImage, .rotate, .stripMetadata, .archive]
        case .video:
            return [.compress, .stripMetadata, .extractAudio, .makeGIF, .archive]
        case .audio:
            return [.compress, .stripMetadata, .archive]
        case .document:
            var values: Set<ToolActionID> = [.compress, .stripMetadata, .archive]
            if format == .pdf { values.insert(.pdfMerge) }
            return values
        case .archive:
            return [.unarchive]
        case .unknown:
            return []
        }
    }

    public static func commonActions(for formats: [FormatID]) -> Set<ToolActionID> {
        guard let first = formats.first else { return [] }
        return formats.dropFirst().reduce(actions(for: first)) { $0.intersection(actions(for: $1)) }
    }
}

public enum ValidatedFileURLs {
    public static func resolve(_ urls: [URL], fileManager: FileManager = .default) -> [URL] {
        urls.filter { url in
            url.isFileURL && fileManager.fileExists(atPath: url.path)
        }
    }
}
