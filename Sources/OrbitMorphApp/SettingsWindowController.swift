import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    let window: NSWindow
    private let host: NSHostingView<SettingsView>
    init(state: AppState) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 580),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "OrbitMorph Settings"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 520)
        host = NSHostingView(rootView: SettingsView(state: state))
        window.contentView = host
        window.center()
    }
    func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func snapshot(to url: URL) throws {
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw NSError(domain: "OrbitMorphSnapshot", code: 1)
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "OrbitMorphSnapshot", code: 2)
        }
        try png.write(to: url)
    }
}
