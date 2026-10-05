import AppKit
import SwiftUI

@MainActor
final class TutorialWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow
    let manager: OnboardingManager
    private let onOpenFolders: () -> Void
    private var host: NSHostingView<TutorialView>!

    init(manager: OnboardingManager, onOpenFolders: @escaping () -> Void) {
        self.manager = manager
        self.onOpenFolders = onOpenFolders
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "OrbitMorph Tutorial"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.center()
        window.delegate = self

        host = NSHostingView(rootView: TutorialView(
            manager: manager,
            state: managerState,
            onDismiss: { [weak self] in self?.dismiss() },
            onOpenFolders: onOpenFolders
        ))
        host.frame = NSRect(x: 0, y: 0, width: 680, height: 520)
        _ = GlassWindowBackground(window: window, host: host, state: managerState, titleKey: "OrbitMorph Tutorial")
    }

    private var managerState: AppState { manager.state }

    func show(resetSession: Bool = true) {
        if resetSession { manager.resetSession() }
        manager.finish()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        manager.skip()
    }

    func snapshot(to url: URL) throws {
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw NSError(domain: "OrbitMorphTutorialSnapshot", code: 1)
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        try WindowSnapshot.write(rep, to: url, appearance: window.effectiveAppearance)
    }
}
