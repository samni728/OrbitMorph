import AppKit
import SwiftUI
import OrbitMorphCore

@MainActor
final class OverlayPanelController {
    private let state: AppState
    private var panel: NSPanel?
    private(set) var model: WheelViewModel?
    private var receiver: DragReceivingView?
    var onFilesResolved: (([URL]) -> Void)?
    var onDrop: ((WheelDisplayItem, [URL]) -> Void)?
    init(state: AppState) { self.state = state }
    func items(for files: [URL], mode: DragMode) -> [WheelDisplayItem] {
        let formats = files.compactMap { FormatID(fileURL: $0) }
        guard formats.count == files.count else { return [] }
        if mode == .conversion {
            let targets = state.policy.commonTargets(for: files)
            return FormatID.allCases.filter { targets.contains($0) }.map { .init(value: .format($0)) }
        }
        let actions = ToolRegistry.commonActions(for: formats, dependencies: state.dependencies)
        return ToolActionID.allCases.filter { actions.contains($0) }.map { .init(value: .tool($0)) }
    }
    func showPlaceholder(mode: DragMode, at point: NSPoint) { show(items: [], mode: mode, at: point) }
    func showForFiles(_ files: [URL], mode: DragMode, at point: NSPoint) {
        let available = items(for: files, mode: mode)
        show(items: available, mode: mode, at: point)
        if available.isEmpty { state.message = "No shared conversion for these files. Check Compatibility and converter diagnostics." }
        model?.onSelect = { [weak self] item in self?.onDrop?(item, files); self?.hide() }
    }
    func show(items: [WheelDisplayItem], mode: DragMode, at screenPoint: NSPoint) {
        hide()
        let model = WheelViewModel(items: items, mode: mode, appearance: state.settings.appearance)
        self.model = model
        model.onCancel = { [weak self] in self?.hide() }
        let size = NSSize(width: 310, height: 310)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false; panel.isMovable = false; panel.isReleasedWhenClosed = false
        let receiver = DragReceivingView(model: model, frame: NSRect(origin: .zero, size: size), resolveItems: { [weak self] files in self?.items(for: files, mode: mode) ?? [] })
        receiver.onFilesResolved = { [weak self] files in self?.onFilesResolved?(files) }
        receiver.onDrop = { [weak self] item, files in self?.onDrop?(item, files); self?.hide() }
        panel.contentView = receiver; self.receiver = receiver
        let screen = NSScreen.screens.first { $0.frame.contains(screenPoint) }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        panel.setFrameOrigin(NSPoint(x: min(max(screenPoint.x - size.width / 2, screen.minX), screen.maxX - size.width),
                                     y: min(max(screenPoint.y - size.height / 2, screen.minY), screen.maxY - size.height)))
        panel.orderFrontRegardless(); self.panel = panel; receiver.animateIn()
    }
    func showDemo() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let values: [FormatID] = [.jpg, .png, .webp, .heic, .pdf, .mp4, .mp3, .zip]
        show(items: values.map { .init(value: .format($0)) }, mode: .conversion, at: NSPoint(x: screen.midX, y: screen.midY))
        model?.selectedIndex = 2
    }
    func snapshot(to url: URL) throws {
        guard let view = panel?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw NSError(domain: "OrbitMorphSnapshot", code: 1) }
        view.layoutSubtreeIfNeeded(); view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "OrbitMorphSnapshot", code: 2) }
        try data.write(to: url)
    }
    func hide() {
        let previous = panel
        receiver?.animateOut()
        panel = nil; receiver = nil; model = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { previous?.orderOut(nil) }
    }
}
