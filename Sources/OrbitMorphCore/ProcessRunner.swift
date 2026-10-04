import Darwin
import Foundation

public struct ProcessInvocation: Sendable {
    public let executable: String
    public let arguments: [String]
    public let workingDirectory: URL?

    public init(executable: String, arguments: [String], workingDirectory: URL? = nil) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
    }
}

public struct ProcessResult: Sendable {
    public let status: Int32
    public let output: String
}

public enum ProcessRunnerError: LocalizedError {
    case failed(ProcessInvocation, Int32, String)
    case timedOut(ProcessInvocation, TimeInterval)

    public var errorDescription: String? {
        switch self {
        case let .failed(invocation, status, output):
            return "Converter failed (\(status)): \(invocation.executable)\n\(output)"
        case let .timedOut(invocation, seconds):
            return "Converter timed out after \(Int(seconds)) seconds: \(invocation.executable)"
        }
    }
}

private final class ProcessTimeoutState: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process
    private var finished = false
    private var expired = false

    init(process: Process) { self.process = process }

    func expire() {
        lock.lock()
        guard !finished, process.isRunning else { lock.unlock(); return }
        expired = true
        lock.unlock()
        if process.isRunning { process.terminate() }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.forceKillIfNeeded()
        }
    }

    private func forceKillIfNeeded() {
        lock.lock()
        let shouldKill = expired && !finished && process.isRunning
        lock.unlock()
        if shouldKill { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
    }

    func complete() -> Bool {
        lock.lock()
        finished = true
        let didExpire = expired
        lock.unlock()
        return didExpire
    }
}

public enum ProcessRunner {
    @discardableResult
    public static func run(_ invocation: ProcessInvocation, timeout: TimeInterval = 900) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: invocation.executable)
        process.arguments = invocation.arguments
        process.currentDirectoryURL = invocation.workingDirectory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()

        let state = ProcessTimeoutState(process: process)
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + max(0.001, timeout))
        timer.setEventHandler { state.expire() }
        timer.resume()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let didTimeout = state.complete()
        timer.cancel()
        if didTimeout { throw ProcessRunnerError.timedOut(invocation, timeout) }
        let output = String(data: data, encoding: .utf8) ?? ""
        let result = ProcessResult(status: process.terminationStatus, output: output)
        guard process.terminationStatus == 0 else {
            throw ProcessRunnerError.failed(invocation, process.terminationStatus, output)
        }
        return result
    }
}
