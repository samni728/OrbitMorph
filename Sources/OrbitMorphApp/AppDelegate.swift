import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = OverlayPanelController()
    private let coordinator = JobCoordinator()
    private lazy var dragMonitor = GlobalDragMonitor(overlay: overlay)
    private var dropWindow: DropWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay.onDrop = { [weak self] item, files in
            self?.dragMonitor.completeDrop()
            self?.coordinator.perform(item: item, files: files)
        }

        if let renderArg = CommandLine.arguments.first(where: { $0.hasPrefix("--render-wheel=") }) {
            NSApp.setActivationPolicy(.regular); overlay.showDemo(); NSApp.activate(ignoringOtherApps: true)
            let path = String(renderArg.dropFirst("--render-wheel=".count))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                do { try self?.overlay.snapshot(to: URL(fileURLWithPath: path)) } catch { fputs("snapshot failed: \(error)\n", stderr) }
                NSApp.terminate(nil)
            }
            return
        }
        if CommandLine.arguments.contains("--demo-wheel") {
            NSApp.setActivationPolicy(.regular); overlay.showDemo(); NSApp.activate(ignoringOtherApps: true); return
        }

        NSApp.setActivationPolicy(.accessory)
        dragMonitor.start()
        let drop = DropWindowController { [weak self] files in
            self?.overlay.showForFiles(files, mode: .conversion, at: NSEvent.mouseLocation)
        }
        dropWindow = drop
        drop.show()
    }

    func applicationWillTerminate(_ notification: Notification) { dragMonitor.stop() }
}
