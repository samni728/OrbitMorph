import Foundation

struct LaunchProcess: Equatable {
    let pid: pid_t
    let bundleIdentifier: String?
    let executableURL: URL?
    let isFinishedLaunching: Bool

    init(pid: pid_t, bundleIdentifier: String?, executableURL: URL?, isFinishedLaunching: Bool = true) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.executableURL = executableURL
        self.isFinishedLaunching = isFinishedLaunching
    }
}

enum LaunchInstancePolicy {
    static let bundleIdentifier = "com.orbitmorph.app"

    static func isExempt(arguments: [String]) -> Bool {
        arguments.dropFirst().contains { argument in
            argument == "--demo-wheel" ||
            ["--render-wheel=", "--render-settings=", "--render-tutorial="].contains(where: argument.hasPrefix)
        }
    }

    static func existing(in applications: [LaunchProcess], currentPID: pid_t) -> LaunchProcess? {
        applications.first { application in
            guard application.pid > 0, application.pid != currentPID else { return false }
            if application.bundleIdentifier == bundleIdentifier { return true }
            // SwiftPM's unbundled debug executable has no Info.plist. A different
            // identified app with the same executable name is not OrbitMorph.
            return application.bundleIdentifier == nil && application.executableURL?.lastPathComponent == "OrbitMorph"
        }
    }
}
