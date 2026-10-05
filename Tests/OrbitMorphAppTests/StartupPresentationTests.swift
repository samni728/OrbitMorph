import XCTest
import OrbitMorphCore
@testable import OrbitMorphApp

final class StartupPresentationTests: XCTestCase {
    func testCompletedUserNormalLaunchStaysMenuBarOnly() {
        var settings = AppSettings.default
        OnboardingState.markCompleted(settings: &settings)
        XCTAssertEqual(StartupPresentationPolicy.initialWindow(settings: settings, arguments: ["OrbitMorph"]), .none)
    }

    func testFirstRunRequestsTutorialInsteadOfDropWindow() {
        XCTAssertEqual(StartupPresentationPolicy.initialWindow(settings: .default, arguments: ["OrbitMorph"]), .tutorial)
    }

    func testExplicitSettingsArgumentWinsOverTutorial() {
        XCTAssertEqual(StartupPresentationPolicy.initialWindow(settings: .default, arguments: ["OrbitMorph", "--settings"]), .settings)
    }
}
