import AppKit
import Combine
import OrbitMorphCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private lazy var overlay = OverlayPanelController(state: state)
    private lazy var coordinator = JobCoordinator(state: state)
    private lazy var dragMonitor = GlobalDragMonitor(overlay: overlay, state: state, suppressesEvent: { [weak self] in
        guard let window = self?.tutorialWindow?.window, window.isVisible else { return false }
        return window.frame.contains(NSEvent.mouseLocation)
    })
    private lazy var settingsWindow = SettingsWindowController(state: state)
    private lazy var onboardingManager = OnboardingManager(
        state: state,
        imageSampleURL: SampleResources.imageURL,
        videoSampleURL: SampleResources.videoURL
    )
    private var tutorialWindow: TutorialWindowController?
    private func makeTutorialWindow() -> TutorialWindowController {
        if let tutorialWindow { return tutorialWindow }
        let window = TutorialWindowController(manager: onboardingManager) { [weak self] in
            guard let self else { return }
            self.state.section = .folders; self.settingsWindow.show()
        }
        tutorialWindow = window
        return window
    }
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
            let tutorialWindow = makeTutorialWindow()
            tutorialWindow.show(resetSession: true)
            let names = ["conversion", "tools", "output", "ready"]
            let requested = argument("--tutorial-step=") ?? "conversion"
            let target = names.firstIndex(of: requested) ?? Int(requested) ?? 0
            for _ in 0..<max(0, min(3, target)) {
                if let item = onboardingManager.makeDemoModel().items.first { onboardingManager.completeDemo(item: item) }
                onboardingManager.next()
            }
            if CommandLine.arguments.contains("--tutorial-preview") { onboardingManager.requestPreview() }
            finishRender { try tutorialWindow.snapshot(to: URL(fileURLWithPath: render)) }
            return
        }
        NSApp.setActivationPolicy(.accessory)
        createMenuBar()
        presentationObserver = NotificationCenter.default.publisher(for: .orbitMorphPresentationChanged, object: state).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.createMenuBar() }
        }
        dragMonitor.start()
        switch StartupPresentationPolicy.initialWindow(settings: state.settings, arguments: CommandLine.arguments) {
        case .settings:
            settingsWindow.show()
        case .tutorial:
            makeTutorialWindow().show(resetSession: true)
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
        item.menu = StatusMenuFactory.makeMenu(state: state, target: self)
        statusItem = item
    }
    @objc private func showSettings() { settingsWindow.show() }
    @objc private func showAbout() { state.section = .about; settingsWindow.show() }
    @objc private func revealOutputs() { if !state.lastOutputs.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(state.lastOutputs) } }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { dragMonitor.stop() }
}
