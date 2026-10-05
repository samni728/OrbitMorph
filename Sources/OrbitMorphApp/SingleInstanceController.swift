import AppKit
import Darwin
import Foundation

@_silgen_name("flock")
private func c_flock(_ descriptor: Int32, _ operation: Int32) -> Int32

enum LaunchClaim: Equatable {
    case launch
    case activateExisting(pid_t)
    case alreadyLaunching
}

/// The lock coordinates launches from different copies before NSApplication or AppState exists.
/// An older version need not hold it: NSWorkspace discovery also detects already-running copies.
final class SingleInstanceController {
    private let lockURL: URL
    private let candidates: () -> [LaunchProcess]
    private let retryCount: Int
    private var lockFD: Int32 = -1

    init(lockURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/com.orbitmorph.app.instance.lock"),
         candidates: @escaping () -> [LaunchProcess] = {
             NSWorkspace.shared.runningApplications.map {
                 LaunchProcess(pid: $0.processIdentifier, bundleIdentifier: $0.bundleIdentifier,
                               executableURL: $0.executableURL, isFinishedLaunching: $0.isFinishedLaunching)
             }
         }, retryCount: Int = 30) {
        self.lockURL = lockURL
        self.candidates = candidates
        self.retryCount = max(0, retryCount)
    }

    deinit { release() }

    func claim() -> LaunchClaim {
        if lockFD >= 0 { return .launch }
        do { try FileManager.default.createDirectory(at: lockURL.deletingLastPathComponent(), withIntermediateDirectories: true) }
        catch { return .alreadyLaunching }
        let fd = Darwin.open(lockURL.path, O_RDWR | O_CREAT | O_CLOEXEC, mode_t(0o600))
        guard fd >= 0 else { return .alreadyLaunching }
        var shouldClose = true
        defer { if shouldClose { _ = Darwin.close(fd) } }
        for attempt in 0...retryCount {
            if c_flock(fd, LOCK_EX | LOCK_NB) == 0 {
                lockFD = fd
                shouldClose = false
                if let existing = matchingApplication(finishedOnly: true) {
                    release()
                    return .activateExisting(existing.pid)
                }
                return .launch
            }
            if let existing = matchingApplication(finishedOnly: true) { return .activateExisting(existing.pid) }
            if attempt < retryCount { Thread.sleep(forTimeInterval: 0.1) }
        }
        return .alreadyLaunching
    }

    func release() {
        guard lockFD >= 0 else { return }
        _ = c_flock(lockFD, LOCK_UN)
        _ = Darwin.close(lockFD)
        lockFD = -1
    }

    private func matchingApplication(finishedOnly: Bool = false) -> LaunchProcess? {
        let applications = candidates().filter { !finishedOnly || $0.isFinishedLaunching }
        return LaunchInstancePolicy.existing(in: applications, currentPID: Darwin.getpid())
    }
}
