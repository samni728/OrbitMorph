import AppKit
import SwiftUI
import QuartzCore
import OrbitMorphCore

@MainActor
final class DragReceivingView: NSView {
    private let host: NSHostingView<RadialWheelView>
    private let model: WheelViewModel
    private let resolveItems: ([URL]) -> [WheelDisplayItem]
    var onFilesResolved: (([URL]) -> Void)?
    var onDrop: ((WheelDisplayItem, [URL]) -> Void)?
    private var files: [URL] = []
    init(model: WheelViewModel, frame: NSRect, resolveItems: @escaping ([URL]) -> [WheelDisplayItem]) {
        self.model = model; self.resolveItems = resolveItems
        host = NSHostingView(rootView: RadialWheelView(model: model))
        super.init(frame: frame)
        wantsLayer = true
        if model.appearance == .glass {
            let glass = NSVisualEffectView(frame: bounds.insetBy(dx: 16, dy: 16))
            glass.material = .hudWindow
            glass.blendingMode = .behindWindow
            glass.state = .active
            glass.wantsLayer = true
            glass.layer?.cornerRadius = glass.bounds.width / 2
            glass.layer?.masksToBounds = true
            addSubview(glass)
        }
        host.frame = bounds; host.autoresizingMask = [.width, .height]; addSubview(host)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func animateIn() {
        guard let layer else { return }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let alpha = CABasicAnimation(keyPath: "opacity")
        alpha.fromValue = 0; alpha.toValue = 1; alpha.duration = reduced ? 0.10 : 0.12
        let scale = CASpringAnimation(keyPath: "transform.scale")
        scale.fromValue = reduced ? 0.96 : 0.88; scale.toValue = 1
        scale.mass = 1; scale.stiffness = 280; scale.damping = 23; scale.duration = reduced ? 0.10 : 0.28
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = reduced ? 0 : -Double.pi / 18; rotation.toValue = 0
        rotation.duration = reduced ? 0.10 : 0.22; rotation.timingFunction = .init(name: .easeOut)
        let group = CAAnimationGroup()
        group.animations = [alpha, scale, rotation]; group.duration = reduced ? 0.10 : 0.28
        layer.add(group, forKey: "OrbitMorph.enter")
    }

    func animateOut() {
        guard let layer else { return }
        let alpha = CABasicAnimation(keyPath: "opacity")
        alpha.fromValue = layer.presentation()?.opacity ?? 1; alpha.toValue = 0; alpha.duration = 0.10
        alpha.fillMode = .forwards; alpha.isRemovedOnCompletion = false
        layer.add(alpha, forKey: "OrbitMorph.exit")
    }
    private func readFiles(_ info: NSDraggingInfo) -> [URL] {
        let objects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return ValidatedFileURLs.resolve(objects)
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        files = readFiles(sender); guard !files.isEmpty else { return [] }
        model.items = resolveItems(files); model.selectedIndex = nil; model.page = 0
        onFilesResolved?(files); _ = draggingUpdated(sender)
        return model.items.isEmpty ? [] : .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let p = convert(sender.draggingLocation, from: nil)
        model.selectedIndex = WheelGeometry.segmentIndex(point: .init(x: p.x, y: bounds.height - p.y),
            center: .init(x: bounds.midX, y: bounds.midY), innerRadius: (bounds.width / 2 - 16) * 0.42,
            outerRadius: bounds.width / 2 - 16, count: model.visibleItems.count)
        return model.selectedIndex == nil ? [] : .copy
    }
    override func draggingExited(_ sender: (any NSDraggingInfo)?) { model.selectedIndex = nil }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        _ = draggingUpdated(sender)
        guard let selected = model.selected, !files.isEmpty else { return false }
        onDrop?(selected, files); return true
    }
    override func scrollWheel(with event: NSEvent) { if abs(event.scrollingDeltaY) > 1 { model.nextPage() } }
}
