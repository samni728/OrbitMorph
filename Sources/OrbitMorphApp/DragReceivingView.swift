import AppKit
import SwiftUI
import OrbitMorphCore

@MainActor
final class DragReceivingView: NSView {
    private let host: NSHostingView<RadialWheelView>
    private let model: WheelViewModel
    private let registry = ConversionRegistry()
    var onFilesResolved: (([URL]) -> Void)?
    var onDrop: ((WheelDisplayItem, [URL]) -> Void)?
    private var files: [URL] = []

    init(model: WheelViewModel, frame: NSRect) {
        self.model = model
        self.host = NSHostingView(rootView: RadialWheelView(model: model))
        super.init(frame: frame)
        host.frame = bounds; host.autoresizingMask = [.width, .height]; addSubview(host)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func readFiles(_ info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        return ValidatedFileURLs.resolve(objects)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        files = readFiles(sender)
        guard !files.isEmpty else { return [] }
        let formats = files.compactMap { FormatID(extension: $0.pathExtension) }
        if model.mode == .conversion {
            let order = FormatID.allCases
            let targets = registry.commonTargets(for: formats)
            model.items = order.filter { targets.contains($0) }.prefix(8).map { WheelDisplayItem(value: .format($0)) }
        } else {
            let actions = ToolRegistry.commonActions(for: formats)
            model.items = ToolActionID.allCases.filter { actions.contains($0) }.prefix(8).map { WheelDisplayItem(value: .tool($0)) }
        }
        onFilesResolved?(files)
        return model.items.isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let p = convert(sender.draggingLocation, from: nil)
        let center = WheelPoint(x: bounds.midX, y: bounds.midY)
        let point = WheelPoint(x: p.x, y: bounds.height - p.y)
        model.selectedIndex = WheelGeometry.segmentIndex(point: point, center: center, innerRadius: 58, outerRadius: 150, count: max(model.items.count, 1))
        return model.selectedIndex == nil ? [] : .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) { model.selectedIndex = nil }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let selected = model.selected else { return false }
        onDrop?(selected, files)
        return true
    }
}
