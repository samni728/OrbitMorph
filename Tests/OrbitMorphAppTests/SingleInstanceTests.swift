import Foundation
import XCTest
@testable import OrbitMorphApp

final class SingleInstanceTests: XCTestCase {
    func testPolicyMatchesCopiedBundleAndDebugExecutableWithoutClaimingOtherApps() {
        let oldCopy = LaunchProcess(pid: 100, bundleIdentifier: "com.orbitmorph.app",
            executableURL: URL(fileURLWithPath: "/Applications/OrbitMorph 06.19.39.app/Contents/MacOS/OrbitMorph"))
        let debug = LaunchProcess(pid: 101, bundleIdentifier: nil,
            executableURL: URL(fileURLWithPath: "/tmp/build/debug/OrbitMorph"))
        let unrelated = LaunchProcess(pid: 102, bundleIdentifier: "com.someone.else",
            executableURL: URL(fileURLWithPath: "/Applications/Another.app/Contents/MacOS/OrbitMorph"))
        let otherDebug = LaunchProcess(pid: 103, bundleIdentifier: nil,
            executableURL: URL(fileURLWithPath: "/tmp/build/debug/OtherTool"))
        XCTAssertEqual(LaunchInstancePolicy.existing(in: [oldCopy], currentPID: 200)?.pid, 100)
        XCTAssertEqual(LaunchInstancePolicy.existing(in: [debug], currentPID: 200)?.pid, 101)
        XCTAssertNil(LaunchInstancePolicy.existing(in: [unrelated, otherDebug], currentPID: 200))
        XCTAssertNil(LaunchInstancePolicy.existing(in: [oldCopy], currentPID: 100))
    }

    func testOnlyStatuslessRenderAndDemoLaunchesBypassSingleInstance() {
        for argument in ["--render-wheel=/tmp/w.png", "--render-settings=/tmp/s.png",
                         "--render-tutorial=/tmp/t.png"] {
            XCTAssertTrue(LaunchInstancePolicy.isExempt(arguments: ["OrbitMorph", argument]), argument)
        }
        for argument in ["--demo-wheel", "--settings", "--language=zhHans", "--style=solid", "--render-unknown=foo"] {
            XCTAssertFalse(LaunchInstancePolicy.isExempt(arguments: ["OrbitMorph", argument]), argument)
        }
    }

    func testFileLockAllowsOneNormalLauncherAndRejectsConcurrentSecond() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphInstanceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let lockURL = directory.appendingPathComponent("app.lock")
        let first = SingleInstanceController(lockURL: lockURL, candidates: { [] }, retryCount: 0)
        let second = SingleInstanceController(lockURL: lockURL, candidates: { [] }, retryCount: 0)
        XCTAssertEqual(first.claim(), .launch)
        XCTAssertEqual(second.claim(), .alreadyLaunching)
        first.release()
        XCTAssertEqual(second.claim(), .launch)
    }

    func testExistingUserInstanceWinsWithoutTermination() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphInstanceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = LaunchProcess(pid: 321, bundleIdentifier: "com.orbitmorph.app",
            executableURL: URL(fileURLWithPath: "/Applications/OrbitMorph.app/Contents/MacOS/OrbitMorph"))
        let controller = SingleInstanceController(lockURL: directory.appendingPathComponent("app.lock"), candidates: { [existing] }, retryCount: 0)
        XCTAssertEqual(controller.claim(), .activateExisting(321))
    }

    func testLockWinnerDoesNotYieldToAnotherUnfinishedConcurrentLaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorphInstanceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let concurrent = LaunchProcess(pid: 987, bundleIdentifier: "com.orbitmorph.app",
            executableURL: URL(fileURLWithPath: "/tmp/other/OrbitMorph"), isFinishedLaunching: false)
        let controller = SingleInstanceController(lockURL: directory.appendingPathComponent("app.lock"),
            candidates: { [concurrent] }, retryCount: 0)
        XCTAssertEqual(controller.claim(), .launch)
        let blocked = SingleInstanceController(lockURL: directory.appendingPathComponent("app.lock"),
            candidates: { [concurrent] }, retryCount: 0)
        XCTAssertEqual(blocked.claim(), .alreadyLaunching)
    }
}
