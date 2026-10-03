import AppKit
import OrbitMorphCore

@MainActor
final class GlobalDragMonitor {
    private let overlay: OverlayPanelController
    private var state = GlobalDragStateMachine()
    private var monitor: Any?

    init(overlay: OverlayPanelController) { self.overlay = overlay }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            let type = event.type
            let shift = event.modifierFlags.contains(.shift)
            let option = event.modifierFlags.contains(.option)
            let point = NSEvent.mouseLocation
            let finder = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
            Task { @MainActor [weak self] in self?.handle(type: type, shift: shift, option: option, point: point, sourceIsFinder: finder) }
        }
        overlay.onFilesResolved = { [weak self] files in _ = self?.state.handle(.filesResolved(count: files.count)) }
    }

    private func handle(type: NSEvent.EventType, shift: Bool, option: Bool, point: NSPoint, sourceIsFinder: Bool) {
        if type == .leftMouseDragged {
            let effect = state.handle(.dragged(shift: shift, option: option, sourceIsFinder: sourceIsFinder))
            if case .show(let mode) = effect { overlay.showPlaceholder(mode: mode, at: point); print("ORBITMORPH drag=armed mode=\(mode.rawValue)") }
        } else if type == .leftMouseUp {
            if state.handle(.mouseUp) == .cancel { overlay.hide(); print("ORBITMORPH drag=cancel") }
        }
    }

    func completeDrop() { _ = state.handle(.dropCompleted) }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
}
