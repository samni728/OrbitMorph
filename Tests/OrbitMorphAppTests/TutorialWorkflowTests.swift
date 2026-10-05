import AppKit
import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class TutorialWorkflowTests: XCTestCase {
    @MainActor func testConversionAndToolsSamplesUnlockTheirOwnStepsOnly() throws {
        let suite = "OrbitMorphTutorial-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(store: .init(defaults: defaults))
        let image = SampleResources.imageURL
        let video = SampleResources.videoURL
        let manager = OnboardingManager(state: state, imageSampleURL: image, videoSampleURL: video)

        XCTAssertEqual(manager.currentStep, .conversion)
        XCTAssertFalse(manager.canAdvance)
        manager.completeDemo(item: .init(value: .tool(.archive)))
        XCTAssertFalse(manager.canAdvance)
        manager.completeDemo(item: .init(value: .format(.jpg)))
        XCTAssertTrue(manager.canAdvance)

        manager.next()
        XCTAssertEqual(manager.currentStep, .tools)
        XCTAssertFalse(manager.canAdvance)
        manager.completeDemo(item: .init(value: .format(.jpg)))
        XCTAssertFalse(manager.canAdvance)
        manager.completeDemo(item: .init(value: .tool(.archive)))
        XCTAssertTrue(manager.canAdvance)
    }

    @MainActor func testOutputAndReadyStepsAdvanceWithoutGesture() throws {
        let state = try makeState()
        let manager = OnboardingManager(state: state,
            imageSampleURL: SampleResources.imageURL,
            videoSampleURL: SampleResources.videoURL)
        manager.completeDemo(item: .init(value: .format(.jpg)))
        manager.next()
        manager.completeDemo(item: .init(value: .tool(.archive)))
        manager.next()
        XCTAssertEqual(manager.currentStep, .output)
        XCTAssertTrue(manager.canAdvance)
        manager.next()
        XCTAssertEqual(manager.currentStep, .ready)
    }

    @MainActor func testSkipAndFinishPersistCompletion() throws {
        let firstState = try makeState()
        let first = OnboardingManager(state: firstState,
            imageSampleURL: SampleResources.imageURL,
            videoSampleURL: SampleResources.videoURL)
        first.skip()
        XCTAssertFalse(OnboardingState.shouldAutoPresent(settings: firstState.settings))

        let secondState = try makeState()
        let second = OnboardingManager(state: secondState,
            imageSampleURL: SampleResources.imageURL,
            videoSampleURL: SampleResources.videoURL)
        second.finish()
        XCTAssertFalse(OnboardingState.shouldAutoPresent(settings: secondState.settings))
    }

    @MainActor func testResettingSimulationDoesNotMakeOnboardingIncompleteAgain() throws {
        let state = try makeState()
        var completed = state.settings
        OnboardingState.markCompleted(settings: &completed)
        state.settings = completed
        let manager = OnboardingManager(state: state,
            imageSampleURL: SampleResources.imageURL,
            videoSampleURL: SampleResources.videoURL)
        manager.completeDemo(item: .init(value: .format(.jpg)))
        manager.next()
        manager.resetSession()
        XCTAssertEqual(manager.currentStep, .conversion)
        XCTAssertFalse(manager.canAdvance)
        XCTAssertFalse(OnboardingState.shouldAutoPresent(settings: state.settings))
    }

    @MainActor func testTutorialWindowIsMovableClosableAndCloseSuppressesFutureAutoPresentation() throws {
        _ = NSApplication.shared
        let state = try makeState()
        let manager = OnboardingManager(state: state,
            imageSampleURL: SampleResources.imageURL,
            videoSampleURL: SampleResources.videoURL)
        let controller = TutorialWindowController(manager: manager, onOpenFolders: {})
        XCTAssertTrue(controller.window.styleMask.contains(.closable))
        XCTAssertTrue(controller.window.styleMask.contains(.titled))
        XCTAssertTrue(controller.window.isMovableByWindowBackground)
        controller.show(resetSession: true)
        XCTAssertTrue(controller.window.isVisible)
        controller.window.close()
        XCTAssertFalse(OnboardingState.shouldAutoPresent(settings: state.settings))
    }

    @MainActor private func makeState() throws -> AppState {
        let suite = "OrbitMorphTutorial-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return AppState(store: .init(defaults: defaults))
    }
}
