import AppKit
import OrbitMorphCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private lazy var overlay = OverlayPanelController(state: state)
    private lazy var coordinator = JobCoordinator(state: state)
    private lazy var dragMonitor = GlobalDragMonitor(overlay: overlay, state: state)
    private lazy var settingsWindow = SettingsWindowController(state: state)
    private var dropWindow: DropWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay.onDrop = { [weak self] item, files in self?.dragMonitor.completeDrop(); self?.coordinator.perform(item: item, files: files) }
        if let render = argument("--render-wheel=") {
            NSApp.setActivationPolicy(.regular); overlay.showDemo()
            finishRender { try self.overlay.snapshot(to: URL(fileURLWithPath: render)) }
            return
        }
        if let render = argument("--render-settings=") {
            if let section = argument("--section="), let value = SettingsSection.allCases.first(where: { $0.rawValue.lowercased() == section }) { state.section = value }
            NSApp.setActivationPolicy(.regular); settingsWindow.show()
            finishRender { try self.settingsWindow.snapshot(to: URL(fileURLWithPath: render)) }
            return
        }
        if CommandLine.arguments.contains("--demo-wheel") {
            NSApp.setActivationPolicy(.regular); overlay.showDemo(); NSApp.activate(ignoringOtherApps: true); return
        }
        NSApp.setActivationPolicy(.accessory)
        createMenuBar()
        let drop = DropWindowController(state: state) { [weak self] files in self?.overlay.showForFiles(files, mode: .conversion, at: NSEvent.mouseLocation) }
        dropWindow = drop
        dragMonitor.start()
        if CommandLine.arguments.contains("--settings") { settingsWindow.show() }
        else { drop.show() }
    }
    private func argument(_ prefix: String) -> String? {
        CommandLine.arguments.first(where: { $0.hasPrefix(prefix) }).map { String($0.dropFirst(prefix.count)) }
    }
    private func finishRender(_ action: @escaping () throws -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            do { try action(); print("ORBITMORPH snapshot=success"); NSApp.terminate(nil) }
            catch { fputs("snapshot failed: \(error)\n", stderr); exit(1) }
        }
    }
    private func createMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.hexagongrid", accessibilityDescription: "OrbitMorph")
        let menu = NSMenu()
        menu.addItem(withTitle: "OrbitMorph · Drop. Spin. Convert.", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, "Open Drop Window", #selector(showDrop), "d")
        add(menu, "Convert Files…", #selector(chooseFiles), "o")
        add(menu, "Reveal Last Outputs", #selector(revealOutputs), "")
        menu.addItem(.separator())
        add(menu, "Settings…", #selector(showSettings), ",")
        add(menu, "About OrbitMorph", #selector(showAbout), "")
        menu.addItem(.separator())
        add(menu, "Quit OrbitMorph", #selector(quit), "q")
        item.menu = menu; statusItem = item
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
    }
    @objc private func showDrop() { dropWindow?.show() }
    @objc private func showSettings() { settingsWindow.show() }
    @objc private func showAbout() { state.section = .about; settingsWindow.show() }
    @objc private func revealOutputs() { if !state.lastOutputs.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(state.lastOutputs) } }
    @objc private func chooseFiles() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        overlay.showForFiles(panel.urls, mode: .conversion, at: NSEvent.mouseLocation)
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { dragMonitor.stop() }
}
