import Foundation

public struct ProcessInvocation: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public struct ProcessResult: Sendable {
    public let status: Int32
    public let output: String
}

public enum ProcessRunnerError: LocalizedError {
    case failed(ProcessInvocation, Int32, String)

    public var errorDescription: String? {
        switch self {
        case let .failed(invocation, status, output):
            return "Converter failed (\(status)): \(invocation.executable)\n\(output)"
        }
    }
}

public enum ProcessRunner {
    @discardableResult
    public static func run(_ invocation: ProcessInvocation) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: invocation.executable)
        process.arguments = invocation.arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        let result = ProcessResult(status: process.terminationStatus, output: output)
        guard process.terminationStatus == 0 else {
            throw ProcessRunnerError.failed(invocation, process.terminationStatus, output)
        }
        return result
    }
}
