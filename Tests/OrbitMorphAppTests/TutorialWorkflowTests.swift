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
        let image = URL(fileURLWithPath: "/tmp/OrbitMorph-Sample.png")
        let video = URL(fileURLWithPath: "/tmp/OrbitMorph-Sample-Video.mp4")
        let manager = OnboardingManager(state: state, imageSampleURL: image, videoSampleURL: video)

        XCTAssertEqual(manager.currentStep, .conversion)
        XCTAssertFalse(manager.canAdvance)
        manager.recordDrop(mode: .tools, files: [image])
        XCTAssertFalse(manager.canAdvance)
        manager.recordDrop(mode: .conversion, files: [image])
        XCTAssertTrue(manager.canAdvance)

        manager.next()
        XCTAssertEqual(manager.currentStep, .tools)
        XCTAssertFalse(manager.canAdvance)
        manager.recordDrop(mode: .conversion, files: [video])
        XCTAssertFalse(manager.canAdvance)
        manager.recordDrop(mode: .tools, files: [video])
        XCTAssertTrue(manager.canAdvance)
    }

    @MainActor func testOutputAndReadyStepsAdvanceWithoutGesture() throws {
        let state = try makeState()
        let manager = OnboardingManager(state: state,
            imageSampleURL: URL(fileURLWithPath: "/tmp/a.png"),
            videoSampleURL: URL(fileURLWithPath: "/tmp/b.mp4"))
        manager.recordDrop(mode: .conversion, files: [manager.imageSampleURL])
        manager.next()
        manager.recordDrop(mode: .tools, files: [manager.videoSampleURL])
        manager.next()
        XCTAssertEqual(manager.currentStep, .output)
        XCTAssertTrue(manager.canAdvance)
        manager.next()
        XCTAssertEqual(manager.currentStep, .ready)
    }

    @MainActor func testSkipAndFinishPersistCompletion() throws {
        let firstState = try makeState()
        let first = OnboardingManager(state: firstState,
            imageSampleURL: URL(fileURLWithPath: "/tmp/a.png"),
            videoSampleURL: URL(fileURLWithPath: "/tmp/b.mp4"))
        first.skip()
        XCTAssertFalse(OnboardingState.shouldAutoPresent(settings: firstState.settings))

        let secondState = try makeState()
        let second = OnboardingManager(state: secondState,
            imageSampleURL: URL(fileURLWithPath: "/tmp/a.png"),
            videoSampleURL: URL(fileURLWithPath: "/tmp/b.mp4"))
        second.finish()
        XCTAssertFalse(OnboardingState.shouldAutoPresent(settings: secondState.settings))
    }

    @MainActor func testManualReopenResetsSessionWithoutMakingOnboardingIncompleteAgain() throws {
        let state = try makeState()
        var completed = state.settings
        OnboardingState.markCompleted(settings: &completed)
        state.settings = completed
        let manager = OnboardingManager(state: state,
            imageSampleURL: URL(fileURLWithPath: "/tmp/a.png"),
            videoSampleURL: URL(fileURLWithPath: "/tmp/b.mp4"))
        manager.recordDrop(mode: .conversion, files: [manager.imageSampleURL])
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
            imageSampleURL: URL(fileURLWithPath: "/tmp/a.png"),
            videoSampleURL: URL(fileURLWithPath: "/tmp/b.mp4"))
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
