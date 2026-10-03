import Foundation

public struct ConversionJob: Sendable {
    public let inputs: [URL]
    public let target: FormatID
    public let outputDirectory: URL?
    public init(inputs: [URL], target: FormatID, outputDirectory: URL? = nil) {
        self.inputs = inputs
        self.target = target
        self.outputDirectory = outputDirectory
    }
}

public struct ConversionResult: Sendable {
    public let inputURL: URL
    public let outputURL: URL
    public let backend: ConversionBackend
}

public enum ConversionEngineError: LocalizedError {
    case unknownFormat(URL)
    case unsupported(FormatID, FormatID)
    case unsupportedTarget(FormatID)
    case missingDependency(String)
    case outputMissing(URL)

    public var errorDescription: String? {
        switch self {
        case .unknownFormat(let url): return "Unknown input format: \(url.lastPathComponent)"
        case .unsupported(let source, let target): return "Unsupported conversion: \(source.rawValue) → \(target.rawValue)"
        case .unsupportedTarget(let target): return "Unsupported target: \(target.rawValue)"
        case .missingDependency(let name): return "Missing converter dependency: \(name)"
        case .outputMissing(let url): return "Converter reported success but no output was created: \(url.path)"
        }
    }
}

public struct ConversionEngine: Sendable {
    public let dependencies: DependencyResolver
    public let registry: ConversionRegistry

    public init(dependencies: DependencyResolver = DependencyResolver()) {
        self.dependencies = dependencies
        self.registry = ConversionRegistry(dependencies: dependencies)
    }

    public func convert(_ job: ConversionJob) throws -> [ConversionResult] {
        try job.inputs.map { input in
            guard let source = FormatID(extension: input.pathExtension) else {
                throw ConversionEngineError.unknownFormat(input)
            }
            guard let route = registry.route(from: source, to: job.target) else {
                throw ConversionEngineError.unsupported(source, job.target)
            }
            let directory = job.outputDirectory ?? input.deletingLastPathComponent()
            let output = OutputNamer.outputURL(for: input, target: job.target, in: directory)

            switch route.backend {
            case .imageMagick:
                guard let path = dependencies.path(for: "magick") else { throw ConversionEngineError.missingDependency("magick") }
                try ProcessRunner.run(ImageMagickAdapter.invocation(input: input, output: output, target: job.target, magickPath: path))
            case .ffmpeg:
                guard let path = dependencies.path(for: "ffmpeg") else { throw ConversionEngineError.missingDependency("ffmpeg") }
                try ProcessRunner.run(FFmpegAdapter.invocation(input: input, output: output, target: job.target, ffmpegPath: path))
            case .pandoc:
                guard let path = dependencies.path(for: "pandoc") else { throw ConversionEngineError.missingDependency("pandoc") }
                try ProcessRunner.run(PandocAdapter.invocation(input: input, output: output, pandocPath: path))
            case .archive:
                try ArchiveAdapter.convert(input: input, output: output, target: job.target, dependencies: dependencies)
            case .textutil:
                guard let path = dependencies.path(for: "textutil") else { throw ConversionEngineError.missingDependency("textutil") }
                try ProcessRunner.run(.init(executable: path, arguments: ["-convert", job.target.fileExtension, "-output", output.path, input.path]))
            case .nativePDF:
                throw ConversionEngineError.unsupported(source, job.target)
            }

            guard FileManager.default.fileExists(atPath: output.path) else { throw ConversionEngineError.outputMissing(output) }
            return ConversionResult(inputURL: input, outputURL: output, backend: route.backend)
        }
    }
}
