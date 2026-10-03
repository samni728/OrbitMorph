import AppKit
import SwiftUI
import OrbitMorphCore

struct DropZoneView: View {
    @State private var hovering = false
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 34, weight: .light)).foregroundStyle(Color(red: 1.0, green: 0.31, blue: 0.12))
            Text("Drop. Spin. Convert.").font(.system(size: 20, weight: .semibold, design: .rounded))
            Text("Drop files here or hold Shift while dragging in Finder").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(width: 390, height: 220)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1))
        .padding(22)
    }
}

@MainActor
final class DropZoneReceivingView: NSView {
    private let host = NSHostingView(rootView: DropZoneView())
    var onFiles: (([URL]) -> Void)?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        host.frame = bounds; host.autoresizingMask = [.width, .height]; addSubview(host)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { read(sender).isEmpty ? [] : .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = read(sender); guard !files.isEmpty else { return false }; onFiles?(files); return true
    }
    private func read(_ info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        return ValidatedFileURLs.resolve(urls)
    }
}

@MainActor
final class DropWindowController {
    let window: NSWindow
    private let receiver: DropZoneReceivingView
    init(onFiles: @escaping ([URL]) -> Void) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 434, height: 264), styleMask: [.borderless, .titled, .closable], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden; window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
        receiver = DropZoneReceivingView(frame: NSRect(x: 0, y: 0, width: 434, height: 264)); receiver.onFiles = onFiles; window.contentView = receiver; window.center()
    }
    func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
}
