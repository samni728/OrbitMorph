import AppKit
import SwiftUI

@MainActor
final class SampleDragSourceView: NSView, NSDraggingSource {
    private var image: NSImage?
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        image = NSImage(contentsOf: fileURL) ?? NSWorkspace.shared.icon(forFile: fileURL.path)
        setAccessibilityElement(true)
        setAccessibilityLabel("Drag sample file")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).addClip()
        let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let rect = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
        image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
}

struct SampleDragSourceRepresentable: NSViewRepresentable {
    let url: URL
    var accessibilityLabel: String = "Drag sample file"

    func makeNSView(context: Context) -> SampleDragSourceView {
        let view = SampleDragSourceView(fileURL: url)
        view.setAccessibilityLabel(accessibilityLabel)
        return view
    }

    func updateNSView(_ nsView: SampleDragSourceView, context: Context) { nsView.setAccessibilityLabel(accessibilityLabel) }
}
