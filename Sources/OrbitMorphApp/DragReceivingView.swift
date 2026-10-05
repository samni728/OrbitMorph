import AppKit
import SwiftUI
import Combine
import QuartzCore
import OrbitMorphCore

@MainActor
final class DragReceivingView: NSView {
    private let host: NSHostingView<RadialWheelView>
    private let model: WheelViewModel
    private let resolveItems: ([URL]) -> [WheelDisplayItem]
    private let feedback: WheelFeedbackController
    private let feedbackEnabled: () -> Bool
    var onFilesResolved: (([URL]) -> Void)?
    var onDrop: ((WheelDisplayItem, [URL]) -> Void)?
    private var files: [URL] = []
    private var glassBackground: NSVisualEffectView?
    private var presentationObserver: AnyCancellable?
    private var accessibilityObserver: AnyCancellable?
    private var pageObserver: AnyCancellable?
    private var pageDwell = WheelPageDwellState()
    private var pendingPageWork: DispatchWorkItem?
    private var pendingPage: Int?
    private var pageDwellGeneration = 0
    private var dragSessionActive = false
    init(
        model: WheelViewModel,
        frame: NSRect,
        resolveItems: @escaping ([URL]) -> [WheelDisplayItem],
        feedback: WheelFeedbackController = WheelFeedbackController(),
        feedbackEnabled: @escaping () -> Bool = { true }
    ) {
        self.model = model
        self.resolveItems = resolveItems
        self.feedback = feedback
        self.feedbackEnabled = feedbackEnabled
        host = NSHostingView(rootView: RadialWheelView(model: model))
        super.init(frame: frame)
        wantsLayer = true
        if GlassPolicy.usesMaterial(appearance: model.appearance) {
            let glass = NSVisualEffectView(frame: bounds.insetBy(dx: 16, dy: 16))
            glass.material = .hudWindow
            glass.blendingMode = .behindWindow
            glass.state = .active
            glass.alphaValue = 0.78
            glass.wantsLayer = true
            glass.layer?.cornerRadius = glass.bounds.width / 2
            glass.layer?.masksToBounds = true
            addSubview(glass)
            glassBackground = glass
        }
        host.frame = bounds; host.autoresizingMask = [.width, .height]; addSubview(host)
        presentationObserver = model.$appearance.sink { [weak self] appearance in self?.refreshGlass(appearance: appearance) }
        accessibilityObserver = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refreshGlass(appearance: self.model.appearance)
            }
        }
        pageObserver = model.$page.sink { [weak self] _ in self?.cancelPageDwell() }
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func refreshGlass(appearance: AppAppearance) {
        let enabled = GlassPolicy.usesMaterial(appearance: appearance)
        if enabled, glassBackground == nil {
            let glass = NSVisualEffectView(frame: bounds.insetBy(dx: 16, dy: 16))
            glass.material = .hudWindow; glass.blendingMode = .behindWindow; glass.state = .active
            glass.alphaValue = 0.78; glass.wantsLayer = true
            glass.layer?.cornerRadius = glass.bounds.width / 2; glass.layer?.masksToBounds = true
            addSubview(glass, positioned: .below, relativeTo: host)
            glassBackground = glass
        }
        glassBackground?.isHidden = !enabled
    }

    func animateIn() {
        guard let layer else { return }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let alpha = CABasicAnimation(keyPath: "opacity")
        alpha.fromValue = 0; alpha.toValue = 1; alpha.duration = reduced ? 0.10 : 0.12
        let scale = CASpringAnimation(keyPath: "transform.scale")
        scale.fromValue = reduced ? 0.96 : 0.88; scale.toValue = 1
        scale.mass = 1; scale.stiffness = 280; scale.damping = 23; scale.duration = reduced ? 0.10 : 0.28
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = reduced ? 0 : -Double.pi / 18; rotation.toValue = 0
        rotation.duration = reduced ? 0.10 : 0.22; rotation.timingFunction = .init(name: .easeOut)
        let group = CAAnimationGroup()
        group.animations = [alpha, scale, rotation]; group.duration = reduced ? 0.10 : 0.28
        layer.add(group, forKey: "OrbitMorph.enter")
    }

    func animateOut() {
        cancelPageDwell(); dragSessionActive = false
        guard let layer else { return }
        let alpha = CABasicAnimation(keyPath: "opacity")
        alpha.fromValue = layer.presentation()?.opacity ?? 1; alpha.toValue = 0; alpha.duration = 0.10
        alpha.fillMode = .forwards; alpha.isRemovedOnCompletion = false
        layer.add(alpha, forKey: "OrbitMorph.exit")
    }
    private func readFiles(_ info: NSDraggingInfo) -> [URL] {
        let objects = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return ValidatedFileURLs.resolve(objects)
    }
    private func cancelPageDwell() {
        pendingPageWork?.cancel(); pendingPageWork = nil; pendingPage = nil
        pageDwell.cancel(); pageDwellGeneration &+= 1
    }

    private func pageCandidate(at point: NSPoint) -> Int? {
        let radius = (min(bounds.width, bounds.height) / 2 - 16) * 0.34
        return WheelPagination.pageIndex(point: .init(x: point.x, y: bounds.minY + bounds.maxY - point.y),
            center: .init(x: bounds.midX, y: bounds.midY), radius: radius, pageCount: model.pageCount)
    }

    private func updatePageDwell(candidate: Int?) {
        guard dragSessionActive, !files.isEmpty, let candidate, candidate != model.page else {
            cancelPageDwell(); return
        }
        if candidate != pendingPage {
            cancelPageDwell()
            pendingPage = candidate
            _ = pageDwell.update(candidate: candidate, currentPage: model.page, now: ProcessInfo.processInfo.systemUptime)
            let generation = pageDwellGeneration
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.dragSessionActive, self.pageDwellGeneration == generation,
                          self.pendingPage == candidate, candidate < self.model.pageCount,
                          let target = self.pageDwell.update(candidate: candidate, currentPage: self.model.page, now: ProcessInfo.processInfo.systemUptime) else { return }
                    self.pendingPageWork = nil; self.pendingPage = nil
                    self.model.page = target
                    self.feedback.selectionChanged(to: nil, enabled: self.feedbackEnabled())
                }
            }
            pendingPageWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + pageDwell.delay, execute: work)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        cancelPageDwell(); dragSessionActive = false
        files = readFiles(sender); guard !files.isEmpty else { return [] }
        dragSessionActive = true
        model.items = resolveItems(files); model.selectedIndex = nil; model.page = 0
        onFilesResolved?(files); _ = draggingUpdated(sender)
        return model.items.isEmpty ? [] : .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let p = convert(sender.draggingLocation, from: nil)
        let candidate = pageCandidate(at: p)
        updatePageDwell(candidate: candidate)
        let index = WheelGeometry.segmentIndex(point: .init(x: p.x, y: bounds.minY + bounds.maxY - p.y),
            center: .init(x: bounds.midX, y: bounds.midY), innerRadius: (min(bounds.width, bounds.height) / 2 - 16) * 0.42,
            outerRadius: min(bounds.width, bounds.height) / 2 - 16, count: model.visibleItems.count)
        feedback.selectionChanged(to: index, enabled: feedbackEnabled())
        model.selectedIndex = index
        return index != nil || (candidate != nil && dragSessionActive && !files.isEmpty) ? .copy : []
    }
    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        cancelPageDwell(); dragSessionActive = false
        feedback.selectionChanged(to: nil, enabled: feedbackEnabled())
        model.selectedIndex = nil
    }
    override func draggingEnded(_ sender: NSDraggingInfo) {
        cancelPageDwell(); dragSessionActive = false; model.selectedIndex = nil
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { cancelPageDwell(); dragSessionActive = false }
        super.viewWillMove(toWindow: newWindow)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { cancelPageDwell(); dragSessionActive = false }
        _ = draggingUpdated(sender)
        guard let selected = model.selected, !files.isEmpty else { return false }
        onDrop?(selected, files); return true
    }
    override func scrollWheel(with event: NSEvent) { if abs(event.scrollingDeltaY) > 1 { model.nextPage() } }
}
