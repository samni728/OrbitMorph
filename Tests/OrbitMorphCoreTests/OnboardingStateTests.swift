import XCTest
@testable import OrbitMorphCore

final class OnboardingStateTests: XCTestCase {
    func testLegacySettingsAutoPresentCurrentOnboarding() throws {
        let legacy = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appearance":"glass"}"#.utf8))
        XCTAssertEqual(legacy.onboardingCompletedVersion, 0)
        XCTAssertTrue(OnboardingState.shouldAutoPresent(settings: legacy))
    }

    func testCompletedOnboardingDoesNotAutoPresent() {
        var settings = AppSettings.default
        OnboardingState.markCompleted(settings: &settings)
        XCTAssertEqual(settings.onboardingCompletedVersion, OnboardingState.currentVersion)
        XCTAssertFalse(OnboardingState.shouldAutoPresent(settings: settings))
    }

    func testCompletionRoundTripsThroughSettingsStore() throws {
        let suite = "OrbitMorphOnboarding-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.default
        OnboardingState.markCompleted(settings: &settings)
        try store.save(settings)
        let restored = try store.load()
        XCTAssertEqual(restored.onboardingCompletedVersion, OnboardingState.currentVersion)
        XCTAssertFalse(OnboardingState.shouldAutoPresent(settings: restored))
    }

    func testFutureOnboardingVersionCanAutoPresentAgain() {
        var settings = AppSettings.default
        settings.onboardingCompletedVersion = max(0, OnboardingState.currentVersion - 1)
        XCTAssertTrue(OnboardingState.shouldAutoPresent(settings: settings))
    }
}
