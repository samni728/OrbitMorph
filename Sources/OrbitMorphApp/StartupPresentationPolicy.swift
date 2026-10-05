import Foundation
import OrbitMorphCore

enum StartupWindow: Equatable {
    case none
    case tutorial
    case settings
}

enum StartupPresentationPolicy {
    static func initialWindow(settings: AppSettings, arguments: [String]) -> StartupWindow {
        if arguments.contains("--settings") { return .settings }
        return OnboardingState.shouldAutoPresent(settings: settings) ? .tutorial : .none
    }
}
