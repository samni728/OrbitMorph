import Combine
import Foundation
import OrbitMorphCore

enum TutorialStep: Int, CaseIterable, Hashable {
    case conversion, tools, output, ready
}

/// Tutorial-only state. Demonstrations never enter JobCoordinator or ConversionEngine.
@MainActor
final class OnboardingManager: ObservableObject {
    @Published private(set) var currentStep: TutorialStep = .conversion
    @Published private(set) var completedGestureSteps: Set<TutorialStep> = []
    @Published private(set) var demoResult: String?
    @Published private(set) var previewRevision = 0
    @Published var demoSample: FormatID = .png { didSet { demoResult = nil } }
    let imageSampleURL: URL
    let videoSampleURL: URL
    let state: AppState

    init(state: AppState, imageSampleURL: URL, videoSampleURL: URL) {
        self.state = state; self.imageSampleURL = imageSampleURL; self.videoSampleURL = videoSampleURL
    }
    var sourceURL: URL { currentStep == .tools || demoSample == .mp4 ? videoSampleURL : imageSampleURL }
    var demoMode: DragMode { currentStep == .tools ? .tools : .conversion }
    var canAdvance: Bool { currentStep == .output || currentStep == .ready || completedGestureSteps.contains(currentStep) }

    func makeDemoModel() -> WheelViewModel {
        let items: [WheelDisplayItem]
        if demoMode == .conversion {
            let targets = state.policy.commonTargets(for: [sourceURL])
            items = FormatID.allCases.filter { targets.contains($0) }.map { .init(value: .format($0)) }
        } else {
            let actions = ToolRegistry.commonActions(for: [.mp4], dependencies: state.dependencies)
            items = ToolActionID.allCases.filter { actions.contains($0) }.map { .init(value: .tool($0)) }
        }
        return WheelViewModel(items: items, mode: demoMode, appearance: state.settings.appearance, language: state.settings.language)
    }
    func completeDemo(item: WheelDisplayItem) {
        guard currentStep == .conversion || currentStep == .tools,
              makeDemoModel().items.contains(item) else { return }
        switch item.value {
        case .format(let target): demoResult = sourceURL.deletingPathExtension().lastPathComponent + "." + target.fileExtension
        case .tool(let action): demoResult = state.L(action.label)
        }
        completedGestureSteps.insert(currentStep)
    }
    func requestPreview() { previewRevision &+= 1 }
    func next() {
        guard canAdvance, let next = TutorialStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next; demoResult = nil
    }
    func back() {
        guard let previous = TutorialStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous; demoResult = nil
    }
    func resetSession() { currentStep = .conversion; completedGestureSteps = []; demoSample = .png; demoResult = nil }
    func skip() { finish() }
    func finish() {
        var updated = state.settings
        OnboardingState.markCompleted(settings: &updated)
        state.settings = updated
    }
}
