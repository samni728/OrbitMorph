import Foundation

public enum OnboardingState {
    public static let currentVersion = 1

    public static func shouldAutoPresent(settings: AppSettings) -> Bool {
        settings.onboardingCompletedVersion < currentVersion
    }

    public static func markCompleted(settings: inout AppSettings) {
        settings.onboardingCompletedVersion = currentVersion
    }
}
