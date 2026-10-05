import AppKit
import SwiftUI
import Combine
import OrbitMorphCore

@MainActor
final class OverlayPanelController {
    private let state: AppState
    private var panel: NSPanel?
    private(set) var model: WheelViewModel?
    private var receiver: DragReceivingView?
    var onFilesResolved: (([URL]) -> Void)?
    var onDrop: ((WheelDisplayItem, [URL]) -> Void)?
    var onInteractionDrop: ((DragMode, WheelDisplayItem, [URL]) -> Void)?
    private var presentationObserver: AnyCancellable?
    init(state: AppState) {
        self.state = state
        presentationObserver = NotificationCenter.default.publisher(for: .orbitMorphPresentationChanged, object: state).sink { [weak self] _ in
            MainActor.assumeIsolated {
                self?.model?.language = state.settings.language
                self?.model?.appearance = state.settings.appearance
            }
        }
    }
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
        model?.onSelect = { [weak self] item in
            self?.onInteractionDrop?(mode, item, files)
            self?.onDrop?(item, files)
            self?.hide()
        }
    }
    func show(items: [WheelDisplayItem], mode: DragMode, at screenPoint: NSPoint) {
        hide()
        let model = WheelViewModel(items: items, mode: mode, appearance: state.settings.appearance, language: state.settings.language)
        self.model = model
        model.onCancel = { [weak self] in self?.hide() }
        let size = NSSize(width: 310, height: 310)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false; panel.isMovable = false; panel.isReleasedWhenClosed = false
        let receiver = DragReceivingView(
            model: model,
            frame: NSRect(origin: .zero, size: size),
            resolveItems: { [weak self] files in self?.items(for: files, mode: mode) ?? [] },
            feedbackEnabled: { [weak self] in self?.state.settings.soundAndHaptics ?? false }
        )
        receiver.onFilesResolved = { [weak self] files in self?.onFilesResolved?(files) }
        receiver.onDrop = { [weak self] item, files in
            self?.onInteractionDrop?(mode, item, files)
            self?.onDrop?(item, files)
            self?.hide()
        }
        panel.contentView = receiver; self.receiver = receiver
        let frame = WheelPlacement.frame(at: .init(x: screenPoint.x, y: screenPoint.y), size: size,
            screens: NSScreen.screens.map { WheelScreen(frame: $0.frame, visibleFrame: $0.visibleFrame) })
        panel.setFrameOrigin(frame.origin)
        panel.orderFrontRegardless(); self.panel = panel; receiver.animateIn()
    }
    func showDemo(pageNumber: Int = 1) {
        let available = items(for: [SampleResources.imageURL], mode: .conversion)
        show(items: available, mode: .conversion, at: NSEvent.mouseLocation)
        guard let model else { return }
        model.page = min(max(pageNumber > 1 ? pageNumber - 1 : 0, 0), model.pageCount - 1)
        model.selectedIndex = model.visibleItems.firstIndex { $0.value == .format(.webp) } ?? (model.visibleItems.isEmpty ? nil : 0)
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
