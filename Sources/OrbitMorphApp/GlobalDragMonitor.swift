import AppKit
import OrbitMorphCore

@MainActor
final class GlobalDragMonitor {
    private let overlay: OverlayPanelController
    private let appState: AppState
    private var state = GlobalDragStateMachine()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var generation = 0
    private var pasteboardGate = FileDragPasteboardGate()
    init(overlay: OverlayPanelController, state: AppState) { self.overlay = overlay; appState = state }
    func start() {
        guard globalMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in self?.handle(event); return event }
        overlay.onFilesResolved = { [weak self] files in _ = self?.state.handle(.filesResolved(count: files.count)) }
    }
    private func dragFiles() -> [URL] {
        let urls = NSPasteboard(name: .drag).readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return ValidatedFileURLs.resolve(urls)
    }
    private func handle(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            pasteboardGate.begin(changeCount: NSPasteboard(name: .drag).changeCount)
            return
        }
        if event.type == .keyDown, event.keyCode == 53 {
            _ = state.handle(.cancelled); generation += 1; overlay.hide(); return
        }
        if event.type == .leftMouseUp {
            pasteboardGate.end()
            let token = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, token == self.generation else { return }
                if self.state.handle(.mouseUp) == .cancel { self.overlay.hide() }
            }
            return
        }
        guard event.type == .leftMouseDragged || (event.type == .flagsChanged && state.phase != .idle) else { return }
        let flags = event.modifierFlags
        let mode = ModifierMatcher.mode(shift: flags.contains(.shift), option: flags.contains(.option),
                                        control: flags.contains(.control), command: flags.contains(.command), settings: appState.settings)
        let files = dragFiles()
        let validSession = pasteboardGate.accepts(changeCount: NSPasteboard(name: .drag).changeCount, validatedFileCount: files.count)
        switch state.handle(.modifiedDrag(mode: mode, sourceHasFiles: validSession)) {
        case .show(let mode):
            generation += 1
            overlay.showForFiles(files, mode: mode, at: NSEvent.mouseLocation)
            _ = state.handle(.filesResolved(count: files.count))
            print("ORBITMORPH drag=armed mode=\(mode.rawValue) validated=\(files.count)")
        case .cancel: generation += 1; overlay.hide()
        default: break
        }
    }
    func completeDrop() {
        _ = state.handle(.filesResolved(count: 1)); _ = state.handle(.dropCompleted); generation += 1
    }
    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil; localMonitor = nil
    }
}
