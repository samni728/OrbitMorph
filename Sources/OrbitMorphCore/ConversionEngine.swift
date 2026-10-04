import Foundation
import PDFKit

public struct ConversionJob: Sendable {
    public let inputs: [URL]
    public let target: FormatID
    public let outputDirectory: URL?
    public let outputDirectories: [URL: URL]
    public let options: FormatDefaults

    public init(
        inputs: [URL], target: FormatID, outputDirectory: URL? = nil,
        outputDirectories: [URL: URL] = [:], options: FormatDefaults = .init()
    ) {
        self.inputs = inputs
        self.target = target
        self.outputDirectory = outputDirectory
        self.outputDirectories = outputDirectories
        self.options = options
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
    case emptyPDF(URL)
    case pdfRenderFailed(URL)
    case unsafeArchiveEntry(String)
    case imageDecodeFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .unknownFormat(let url): return "Unknown input format: \(url.lastPathComponent)"
        case .unsupported(let source, let target): return "Unsupported conversion: \(source.rawValue) → \(target.rawValue)"
        case .unsupportedTarget(let target): return "Unsupported target: \(target.rawValue)"
        case .missingDependency(let name): return "Missing converter dependency: \(name)"
        case .outputMissing(let url): return "Converter reported success but no output was created: \(url.path)"
        case .emptyPDF(let url): return "PDF has no readable pages: \(url.path)"
        case .pdfRenderFailed(let url): return "Could not render PDF page: \(url.path)"
        case .unsafeArchiveEntry(let name): return "Archive contains an unsafe entry: \(name)"
        case .imageDecodeFailed(let url): return "Could not decode image: \(url.path)"
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

    /// A batch is atomic from the caller's perspective: a failed input removes outputs
    /// already committed by this batch and rethrows the conversion error.
    public func convert(_ job: ConversionJob) throws -> [ConversionResult] {
        var completed: [ConversionResult] = []
        do {
            for input in job.inputs {
                guard let source = FormatID(fileURL: input) else {
                    throw ConversionEngineError.unknownFormat(input)
                }
                guard let route = registry.route(from: source, to: job.target) else {
                    throw ConversionEngineError.unsupported(source, job.target)
                }
                let directory = job.outputDirectories[input] ?? job.outputDirectory ?? input.deletingLastPathComponent()
                if route.backend == .nativePDF {
                    guard let document = PDFDocument(url: input), document.pageCount > 0 else {
                        throw ConversionEngineError.emptyPDF(input)
                    }
                    for index in 0..<document.pageCount {
                        guard let page = document.page(at: index) else { throw ConversionEngineError.emptyPDF(input) }
                        let pageSource = directory.appendingPathComponent("\(input.deletingPathExtension().lastPathComponent)-page-\(index + 1).pdf")
                        let temporary = OutputNamer.makeTemporaryOutput(for: job.target, in: directory)
                        defer { try? FileManager.default.removeItem(at: temporary) }
                        try PDFRenderAdapter.render(page: page, target: job.target, output: temporary, options: job.options)
                        let final = try OutputNamer.commitTemporaryOutput(temporary, for: pageSource, target: job.target, in: directory)
                        completed.append(.init(inputURL: input, outputURL: final, backend: .nativePDF))
                    }
                    continue
                }

                let temporary = OutputNamer.makeTemporaryOutput(for: job.target, in: directory)
                defer { try? FileManager.default.removeItem(at: temporary) }
                switch route.backend {
                case .imageMagick:
                    guard let path = dependencies.path(for: "magick") else { throw ConversionEngineError.missingDependency("magick") }
                    try ProcessRunner.run(ImageMagickAdapter.invocation(input: input, output: temporary, target: job.target, magickPath: path, options: job.options))
                case .nativeImageIO:
                    try ImageIOAdapter.convert(input: input, output: temporary, target: job.target, options: job.options)
                case .nativeSubtitle:
                    try SubtitleAdapter.convert(input: input, output: temporary, source: source, target: job.target)
                case .ffmpeg:
                    guard let path = dependencies.path(for: "ffmpeg") else { throw ConversionEngineError.missingDependency("ffmpeg") }
                    try ProcessRunner.run(FFmpegAdapter.invocation(input: input, output: temporary, target: job.target, ffmpegPath: path, options: job.options))
                case .pandoc:
                    guard let path = dependencies.path(for: "pandoc") else { throw ConversionEngineError.missingDependency("pandoc") }
                    try ProcessRunner.run(PandocAdapter.invocation(input: input, output: temporary, pandocPath: path))
                case .archive:
                    try ArchiveAdapter.convert(input: input, output: temporary, target: job.target, dependencies: dependencies, options: job.options)
                case .textutil:
                    guard let path = dependencies.path(for: "textutil") else { throw ConversionEngineError.missingDependency("textutil") }
                    var args = ["-convert", job.target.fileExtension, "-output", temporary.path]
                    if !job.options.preserveMetadata { args.append("-strip") }
                    args.append(input.path)
                    try ProcessRunner.run(.init(executable: path, arguments: args))
                case .nativePDF:
                    break
                }
                guard FileManager.default.fileExists(atPath: temporary.path) else { throw ConversionEngineError.outputMissing(temporary) }
                let final = try OutputNamer.commitTemporaryOutput(temporary, for: input, target: job.target, in: directory)
                completed.append(.init(inputURL: input, outputURL: final, backend: route.backend))
            }
            return completed
        } catch {
            for result in completed { try? FileManager.default.removeItem(at: result.outputURL) }
            throw error
        }
    }
}
