import AppKit
import SwiftUI
import OrbitMorphCore

@MainActor
final class OverlayPanelController {
    private var panel: NSPanel?
    private(set) var model: WheelViewModel?
    private var receiver: DragReceivingView?
    var onFilesResolved: (([URL]) -> Void)?
    var onDrop: ((WheelDisplayItem, [URL]) -> Void)?

    func showPlaceholder(mode: DragMode, at point: NSPoint) {
        let items: [WheelDisplayItem]
        if mode == .conversion {
            items = [.jpg, .png, .webp, .heic, .pdf, .mp4, .mp3, .zip].map { .init(value: .format($0)) }
        } else {
            items = ToolActionID.allCases.prefix(8).map { .init(value: .tool($0)) }
        }
        show(items: items, mode: mode, at: point)
    }

    func showForFiles(_ files: [URL], mode: DragMode, at point: NSPoint) {
        let formats = files.compactMap { FormatID(extension: $0.pathExtension) }
        let items: [WheelDisplayItem]
        if mode == .conversion {
            let targets = ConversionRegistry().commonTargets(for: formats)
            items = FormatID.allCases.filter { targets.contains($0) }.prefix(8).map { .init(value: .format($0)) }
        } else {
            let actions = ToolRegistry.commonActions(for: formats)
            items = ToolActionID.allCases.filter { actions.contains($0) }.prefix(8).map { .init(value: .tool($0)) }
        }
        show(items: items, mode: mode, at: point)
        model?.onSelect = { [weak self] item in self?.onDrop?(item, files); self?.hide() }
    }

    func show(items: [WheelDisplayItem], mode: DragMode, at screenPoint: NSPoint) {
        hide()
        let model = WheelViewModel(items: items, mode: mode); self.model = model
        let size = NSSize(width: 310, height: 310)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]; panel.hidesOnDeactivate = false; panel.isMovable = false
        let receiver = DragReceivingView(model: model, frame: NSRect(origin: .zero, size: size))
        receiver.onFilesResolved = { [weak self] files in self?.onFilesResolved?(files) }
        receiver.onDrop = { [weak self] item, files in self?.onDrop?(item, files); self?.hide() }
        panel.contentView = receiver; self.receiver = receiver
        panel.setFrameOrigin(NSPoint(x: screenPoint.x - size.width / 2, y: screenPoint.y - size.height / 2))
        panel.orderFrontRegardless(); self.panel = panel
    }

    func showDemo() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        showPlaceholder(mode: .conversion, at: NSPoint(x: screen.midX, y: screen.midY)); model?.selectedIndex = 2
    }

    func snapshot(to url: URL) throws {
        guard let view = panel?.contentView else { throw NSError(domain: "OrbitMorphSnapshot", code: 1) }
        view.layoutSubtreeIfNeeded(); guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw NSError(domain: "OrbitMorphSnapshot", code: 2) }
        view.cacheDisplay(in: view.bounds, to: rep); guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "OrbitMorphSnapshot", code: 3) }
        try data.write(to: url)
    }
    func hide() { panel?.orderOut(nil); panel = nil; receiver = nil; model = nil }
}
