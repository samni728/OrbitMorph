import AppKit
import SwiftUI
import OrbitMorphCore

struct DropZoneView: View {
    @ObservedObject var state: AppState
    var body: some View {
        GlassCard(appearance: state.settings.appearance) {
          VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc.fill").font(.system(size: 34, weight: .light)).foregroundStyle(Color(red: 1, green: 0.31, blue: 0.12))
            Text(state.L("Drop. Spin. Convert.")).font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(state.L("Drop files here or hold %@ while dragging in Finder", state.settings.conversionModifier.capitalized))
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if state.isBusy { ProgressView().controlSize(.small) }
            Text(state.displayMessage).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.center)
            if !state.lastOutputs.isEmpty {
                Button(state.L("Reveal output files")) { NSWorkspace.shared.activateFileViewerSelecting(state.lastOutputs) }.controlSize(.small)
            }
          }.frame(maxWidth: .infinity)
        }.environment(\.locale, state.locale).frame(width: 390, height: 260).padding(22)
    }
}

@MainActor
final class DropZoneReceivingView: NSView {
    private let host: NSHostingView<DropZoneView>
    var onFiles: (([URL]) -> Void)?
    init(state: AppState, frame: NSRect) {
        host = NSHostingView(rootView: DropZoneView(state: state)); super.init(frame: frame)
        host.frame = bounds; host.autoresizingMask = [.width, .height]; addSubview(host)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { read(sender).isEmpty ? [] : .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = read(sender); guard !files.isEmpty else { return false }; onFiles?(files); return true
    }
    private func read(_ info: NSDraggingInfo) -> [URL] {
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return ValidatedFileURLs.resolve(urls)
    }
}

@MainActor
final class DropWindowController {
    let window: NSWindow
    private let receiver: DropZoneReceivingView
    init(state: AppState, onFiles: @escaping ([URL]) -> Void) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 434, height: 320), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true; window.isReleasedWhenClosed = false
        receiver = DropZoneReceivingView(state: state, frame: NSRect(x: 0, y: 0, width: 434, height: 320))
        receiver.onFiles = onFiles
        _ = GlassWindowBackground(window: window, host: receiver, state: state, titleKey: "OrbitMorph Drop Window")
        window.center()
    }
    func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
}
