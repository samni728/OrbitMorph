import Combine
import Foundation
import OrbitMorphCore

enum TutorialStep: Int, CaseIterable, Hashable {
    case conversion
    case tools
    case output
    case ready
}

@MainActor
final class OnboardingManager: ObservableObject {
    @Published private(set) var currentStep: TutorialStep = .conversion
    @Published private(set) var completedGestureSteps: Set<TutorialStep> = []

    let imageSampleURL: URL
    let videoSampleURL: URL
    let state: AppState

    init(state: AppState, imageSampleURL: URL, videoSampleURL: URL) {
        self.state = state
        self.imageSampleURL = imageSampleURL
        self.videoSampleURL = videoSampleURL
    }

    var canAdvance: Bool {
        switch currentStep {
        case .conversion, .tools:
            return completedGestureSteps.contains(currentStep)
        case .output, .ready:
            return true
        }
    }

    func recordDrop(mode: DragMode, files: [URL]) {
        guard files.count == 1, let file = files.first else { return }
        switch currentStep {
        case .conversion where mode == .conversion && matches(file, imageSampleURL):
            completedGestureSteps.insert(.conversion)
        case .tools where mode == .tools && matches(file, videoSampleURL):
            completedGestureSteps.insert(.tools)
        default:
            break
        }
    }

    func next() {
        guard canAdvance, let next = TutorialStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func back() {
        guard let previous = TutorialStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    func resetSession() {
        currentStep = .conversion
        completedGestureSteps = []
    }

    func skip() { finish() }

    func finish() {
        var updated = state.settings
        OnboardingState.markCompleted(settings: &updated)
        state.settings = updated
    }

    private func matches(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL == rhs.standardizedFileURL
    }
}
