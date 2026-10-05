import AppKit
import SwiftUI
import OrbitMorphCore

/// Local mouse tracking, with no NSDraggingSession or file pasteboard payload.
/// The wheel is a child view of this canvas, never a floating panel.
@MainActor
final class TutorialDemoCanvas: NSView {
    private let manager: OnboardingManager
    private var model: WheelViewModel
    private let wheelHost: NSHostingView<RadialWheelView>
    private var image: NSImage?
    private var sourceURL: URL
    private var sourceStep: TutorialStep
    private var trackingSample = false
    private var ghostPoint: NSPoint?
    private var generation = 0
    private var lastPreviewRevision = 0
    private var pageCandidate: Int?
    private var pageWork: DispatchWorkItem?
    private(set) var isWheelVisible = false
    private let sampleRect = NSRect(x: 24, y: 74, width: 132, height: 100)
    private let wheelRect = NSRect(x: 300, y: 0, width: 240, height: 240)

    init(manager: OnboardingManager, frame: NSRect) {
        self.manager = manager; model = manager.makeDemoModel()
        wheelHost = NSHostingView(rootView: RadialWheelView(model: model))
        sourceURL = manager.sourceURL; sourceStep = manager.currentStep
        super.init(frame: frame)
        wantsLayer = true; layer?.masksToBounds = true
        image = NSImage(contentsOf: sourceURL) ?? NSWorkspace.shared.icon(forFile: sourceURL.path)
        wheelHost.frame = wheelRect; wheelHost.isHidden = true; wheelHost.wantsLayer = true
        addSubview(wheelHost)
        setAccessibilityElement(true)
        setAccessibilityLabel(manager.state.L("Move the sample toward a format."))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func refresh() {
        if sourceURL != manager.sourceURL || sourceStep != manager.currentStep {
            cancelTracking(); sourceURL = manager.sourceURL; sourceStep = manager.currentStep
            image = NSImage(contentsOf: sourceURL) ?? NSWorkspace.shared.icon(forFile: sourceURL.path)
            model = manager.makeDemoModel(); wheelHost.rootView = RadialWheelView(model: model)
        }
        model.language = manager.state.settings.language; model.appearance = manager.state.settings.appearance
        if manager.previewRevision != lastPreviewRevision {
            lastPreviewRevision = manager.previewRevision; playPreview()
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: sampleRect.insetBy(dx: -8, dy: -8), xRadius: 16, yRadius: 16).fill()
        image?.draw(in: sampleRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor]
        let filename = sourceURL.lastPathComponent as NSString
        filename.draw(at: NSPoint(x: 10, y: 42), withAttributes: attributes)
        if !isWheelVisible {
            let shortcut = manager.demoMode == .conversion ? manager.state.settings.conversionModifier : manager.state.settings.toolsModifier
            let message = manager.state.L("Hold %@ to reveal the wheel.", shortcut.capitalized) as NSString
            message.draw(in: NSRect(x: 282, y: 82, width: 276, height: 54), withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondaryLabelColor])
        }
        if let ghostPoint {
            image?.draw(in: NSRect(x: ghostPoint.x - 16, y: ghostPoint.y - 12, width: 32, height: 24), from: .zero, operation: .sourceOver, fraction: 0.7, respectFlipped: true, hints: nil)
        }
    }

    override func mouseDown(with event: NSEvent) {
        cancelTracking()
        trackingSample = sampleRect.contains(convert(event.locationInWindow, from: nil))
    }
    override func mouseDragged(with event: NSEvent) {
        guard trackingSample else { return }
        let flags = event.modifierFlags
        let mode = ModifierMatcher.mode(shift: flags.contains(.shift), option: flags.contains(.option), control: flags.contains(.control), command: flags.contains(.command), settings: manager.state.settings)
        guard mode == manager.demoMode else { hideWheel(); return }
        revealWheel()
        let point = convert(event.locationInWindow, from: nil)
        ghostPoint = point; select(at: point); needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        // Recheck the modifier on release, so releasing it cancels the demonstration.
        if trackingSample { mouseDragged(with: event) }
        if trackingSample, isWheelVisible, let item = model.selected { manager.completeDemo(item: item) }
        cancelTracking()
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { cancelTracking() }
        super.viewWillMove(toWindow: newWindow)
    }

    private func revealWheel() {
        guard !isWheelVisible else { return }
        isWheelVisible = true; wheelHost.isHidden = false
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let animation = CASpringAnimation(keyPath: "transform.scale")
            animation.fromValue = 0.88; animation.toValue = 1; animation.stiffness = 280; animation.damping = 23; animation.duration = 0.25
            wheelHost.layer?.add(animation, forKey: "tutorial.enter")
        }
        needsDisplay = true
    }
    private func hideWheel() {
        cancelPage(); isWheelVisible = false; wheelHost.isHidden = true; model.selectedIndex = nil; ghostPoint = nil; needsDisplay = true
    }
    private func cancelTracking() { generation &+= 1; trackingSample = false; hideWheel() }
    private func cancelPage() { pageWork?.cancel(); pageWork = nil; pageCandidate = nil }

    private func select(at point: NSPoint) {
        let local = WheelPoint(x: point.x - wheelRect.minX, y: wheelRect.maxY - point.y)
        let center = WheelPoint(x: 120, y: 120)
        model.selectedIndex = WheelGeometry.segmentIndex(point: local, center: center, innerRadius: 104 * 0.42, outerRadius: 104, count: model.visibleItems.count)
        let candidate = WheelPagination.pageIndex(point: local, center: center, radius: 104 * 0.34, pageCount: model.pageCount)
        guard let candidate, candidate != model.page else { cancelPage(); return }
        guard candidate != pageCandidate else { return }
        cancelPage(); pageCandidate = candidate
        let token = generation
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == token, self.trackingSample, self.isWheelVisible,
                      self.pageCandidate == candidate else { return }
                self.model.page = candidate; self.cancelPage()
            }
        }
        pageWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func playPreview() {
        cancelTracking(); revealWheel(); ghostPoint = NSPoint(x: 230, y: 124); needsDisplay = true
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.generation == token, self.window?.isVisible == true else { return }
            self.ghostPoint = NSPoint(x: 420, y: 205)
            self.model.selectedIndex = self.model.visibleItems.isEmpty ? nil : 0
            self.needsDisplay = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self, self.generation == token, self.window?.isVisible == true,
                  let item = self.model.selected else { return }
            self.ghostPoint = nil; self.manager.completeDemo(item: item); self.needsDisplay = true
        }
    }
}

struct TutorialDemoRepresentable: NSViewRepresentable {
    let manager: OnboardingManager
    func makeNSView(context: Context) -> TutorialDemoCanvas {
        TutorialDemoCanvas(manager: manager, frame: NSRect(x: 0, y: 0, width: 580, height: 240))
    }
    func updateNSView(_ nsView: TutorialDemoCanvas, context: Context) { nsView.refresh() }
}
