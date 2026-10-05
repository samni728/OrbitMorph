import SwiftUI
import AppKit
import Combine
import OrbitMorphCore

enum GlassPolicy {
    static func usesMaterial(appearance: AppAppearance, reduceTransparency: Bool, increaseContrast: Bool) -> Bool {
        appearance == .glass && !reduceTransparency && !increaseContrast
    }
    @MainActor static func usesMaterial(appearance: AppAppearance) -> Bool {
        usesMaterial(appearance: appearance, reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                     increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
    }
}

struct GlassCard<Content: View>: View {
    let title: String?
    let appearance: AppAppearance
    let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ title: String? = nil, appearance: AppAppearance = .glass, @ViewBuilder content: () -> Content) {
        self.title = title; self.appearance = appearance; self.content = content()
    }

    var body: some View {
        let glass = GlassPolicy.usesMaterial(appearance: appearance, reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased)
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.system(.callout, design: .rounded).weight(.semibold)) }
            content
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(glass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(colors: glass ? [.white.opacity(0.5), .white.opacity(0.08), .primary.opacity(0.1)] : [.primary.opacity(0.2), .primary.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: contrast == .increased ? 2 : 1)
        }
        .shadow(color: .black.opacity(glass ? 0.05 : 0), radius: 12, y: 4)
    }
}

@MainActor
final class GlassWindowBackground: NSVisualEffectView {
    private weak var appState: AppState?
    private weak var ownerWindow: NSWindow?
    private let titleKey: String
    private var presentationObserver: AnyCancellable?
    private var accessibilityObserver: AnyCancellable?

    init(window: NSWindow, host: NSView, state: AppState, titleKey: String) {
        self.appState = state; self.ownerWindow = window; self.titleKey = titleKey
        super.init(frame: host.frame)
        autoresizingMask = [.width, .height]
        wantsLayer = true; layer?.cornerRadius = 20; layer?.masksToBounds = true
        host.frame = bounds; host.autoresizingMask = [.width, .height]
        host.wantsLayer = true; host.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(host)
        window.contentView = self
        presentationObserver = NotificationCenter.default.publisher(for: .orbitMorphPresentationChanged, object: state).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        accessibilityObserver = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func refresh() {
        guard let state = appState, let window = ownerWindow else { return }
        let glass = GlassPolicy.usesMaterial(appearance: state.settings.appearance)
        material = glass ? .hudWindow : .windowBackground
        blendingMode = glass ? .behindWindow : .withinWindow
        super.state = .active
        window.isOpaque = !glass
        window.backgroundColor = glass ? .clear : .windowBackgroundColor
        window.title = state.L(titleKey)
    }
}

@MainActor
enum WindowSnapshot {
    static func write(_ source: NSBitmapImageRep, to url: URL, appearance: NSAppearance) throws {
        // Host cacheDisplay omits the compositor's behind-window material. Give
        // exported previews a stable light/dark matte while keeping live UI clear.
        guard let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: source.pixelsWide, pixelsHigh: source.pixelsHigh,
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: image) else { throw NSError(domain: "OrbitMorphSnapshot", code: 3) }
        let rect = NSRect(x: 0, y: 0, width: source.pixelsWide, height: source.pixelsHigh)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        appearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            NSBezierPath(rect: rect).fill()
        }
        let sourceImage = NSImage(size: rect.size)
        sourceImage.addRepresentation(source)
        sourceImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let png = image.representation(using: .png, properties: [:]) else { throw NSError(domain: "OrbitMorphSnapshot", code: 2) }
        try png.write(to: url)
    }
}
