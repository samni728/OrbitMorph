import AppKit
import Combine
import OrbitMorphCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private lazy var overlay = OverlayPanelController(state: state)
    private lazy var coordinator = JobCoordinator(state: state)
    private lazy var dragMonitor = GlobalDragMonitor(overlay: overlay, state: state)
    private lazy var settingsWindow = SettingsWindowController(state: state)
    private lazy var onboardingManager = OnboardingManager(
        state: state,
        imageSampleURL: SampleResources.imageURL,
        videoSampleURL: SampleResources.videoURL
    )
    private lazy var tutorialWindow = TutorialWindowController(manager: onboardingManager) { [weak self] in
        guard let self else { return }
        self.state.section = .folders
        self.settingsWindow.show()
    }
    private var dropWindow: DropWindowController?
    private var statusItem: NSStatusItem?
    private var presentationObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains(where: { $0.hasPrefix("--render-") || $0.hasPrefix("--language=") || $0.hasPrefix("--style=") }) {
            state.applyPresentation(language: argument("--language=").flatMap(AppLanguage.init(rawValue:)), appearance: argument("--style=").flatMap(AppAppearance.init(rawValue:)))
        }
        if let appearance = argument("--appearance=") {
            NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        }
        overlay.onDrop = { [weak self] item, files in self?.dragMonitor.completeDrop(); self?.coordinator.perform(item: item, files: files) }
        overlay.onInteractionDrop = { [weak self] mode, _, files in
            self?.onboardingManager.recordDrop(mode: mode, files: files)
        }
        if let render = argument("--render-wheel=") {
            NSApp.setActivationPolicy(.regular); overlay.showDemo(pageNumber: Int(argument("--wheel-page=") ?? "1") ?? 1)
            finishRender { try self.overlay.snapshot(to: URL(fileURLWithPath: render)) }
            return
        }
        if let render = argument("--render-settings=") {
            if let section = argument("--section="), let value = SettingsSection.allCases.first(where: { $0.rawValue.lowercased() == section }) { state.section = value }
            NSApp.setActivationPolicy(.regular); settingsWindow.show()
            finishRender { try self.settingsWindow.snapshot(to: URL(fileURLWithPath: render)) }
            return
        }
        if let render = argument("--render-tutorial=") {
            NSApp.setActivationPolicy(.regular)
            tutorialWindow.show(resetSession: true)
            let names = ["conversion", "tools", "output", "ready"]
            let requested = argument("--tutorial-step=") ?? "conversion"
            let target = names.firstIndex(of: requested) ?? Int(requested) ?? 0
            for _ in 0..<max(0, min(3, target)) {
                if onboardingManager.currentStep == .conversion { onboardingManager.recordDrop(mode: .conversion, files: [onboardingManager.imageSampleURL]) }
                if onboardingManager.currentStep == .tools { onboardingManager.recordDrop(mode: .tools, files: [onboardingManager.videoSampleURL]) }
                onboardingManager.next()
            }
            finishRender { try self.tutorialWindow.snapshot(to: URL(fileURLWithPath: render)) }
            return
        }
        if CommandLine.arguments.contains("--demo-wheel") {
            NSApp.setActivationPolicy(.regular); overlay.showDemo(); NSApp.activate(ignoringOtherApps: true); return
        }
        NSApp.setActivationPolicy(.accessory)
        createMenuBar()
        presentationObserver = NotificationCenter.default.publisher(for: .orbitMorphPresentationChanged, object: state).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.createMenuBar() }
        }
        let drop = DropWindowController(state: state) { [weak self] files in self?.overlay.showForFiles(files, mode: .conversion, at: NSEvent.mouseLocation) }
        dropWindow = drop
        dragMonitor.start()
        switch StartupPresentationPolicy.initialWindow(settings: state.settings, arguments: CommandLine.arguments) {
        case .settings:
            settingsWindow.show()
        case .tutorial:
            tutorialWindow.show(resetSession: true)
        case .none:
            break
        }
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
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.hexagongrid", accessibilityDescription: "OrbitMorph")
        let menu = NSMenu()
        menu.addItem(withTitle: state.L("OrbitMorph · Drop. Spin. Convert."), action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, state.L("Open Drop Window"), #selector(showDrop), "d")
        add(menu, state.L("Show Tutorial"), #selector(showTutorial), "")
        add(menu, state.L("Convert Files…"), #selector(chooseFiles), "o")
        add(menu, state.L("Reveal Last Outputs"), #selector(revealOutputs), "")
        menu.addItem(.separator())
        add(menu, state.L("Settings…"), #selector(showSettings), ",")
        add(menu, state.L("About OrbitMorph"), #selector(showAbout), "")
        menu.addItem(.separator())
        add(menu, state.L("Quit OrbitMorph"), #selector(quit), "q")
        item.menu = menu; statusItem = item
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
    }
    @objc private func showDrop() { dropWindow?.show() }
    @objc private func showTutorial() { tutorialWindow.show(resetSession: true) }
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
