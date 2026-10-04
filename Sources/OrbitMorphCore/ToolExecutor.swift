import Foundation
import PDFKit

public enum ToolExecutor {
    public static func perform(_ action: ToolActionID, files: [URL], dependencies: DependencyResolver,
                               outputDirectory: URL? = nil, outputDirectories: [URL: URL] = [:]) throws -> [URL] {
        let formats = files.compactMap { FormatID(fileURL: $0) }
        guard !files.isEmpty, formats.count == files.count,
              ToolRegistry.commonActions(for: formats, dependencies: dependencies).contains(action) else {
            throw ConversionEngineError.unsupportedTarget(formats.first ?? .zip)
        }
        if action == .extractAudio || action == .makeGIF {
            return try ConversionEngine(dependencies: dependencies).convert(.init(inputs: files,
                target: action == .extractAudio ? .mp3 : .gif, outputDirectory: outputDirectory, outputDirectories: outputDirectories)).map(\.outputURL)
        }
        if action == .pdfMerge {
            let result = PDFDocument()
            for file in files {
                guard let doc = PDFDocument(url: file), doc.pageCount > 0 else { throw ConversionEngineError.emptyPDF(file) }
                for i in 0..<doc.pageCount {
                    guard let page = doc.page(at: i) else { throw ConversionEngineError.emptyPDF(file) }
                    result.insert(page, at: result.pageCount)
                }
            }
            let directory = outputDirectories[files[0]] ?? outputDirectory ?? files[0].deletingLastPathComponent()
            let temporary = OutputNamer.makeTemporaryOutput(for: .pdf, in: directory)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard result.write(to: temporary) else { throw ConversionEngineError.outputMissing(temporary) }
            let source = directory.appendingPathComponent(files[0].deletingPathExtension().lastPathComponent + "-merged.pdf")
            return [try OutputNamer.commitTemporaryOutput(temporary, for: source, target: .pdf, in: directory)]
        }
        var completed: [URL] = []
        do {
            for (input, format) in zip(files, formats) {
                let directory = outputDirectories[input] ?? outputDirectory ?? input.deletingLastPathComponent()
                if action == .unarchive {
                    let temporary = directory.appendingPathComponent(".OrbitMorph-extract-\(UUID().uuidString)")
                    defer { try? FileManager.default.removeItem(at: temporary) }
                    try ArchiveAdapter.extract(input: input, into: temporary, dependencies: dependencies)
                    var index = 0
                    while true {
                        let suffix = index == 0 ? "" : "-\(index + 1)"
                        let destination = directory.appendingPathComponent(input.deletingPathExtension().lastPathComponent + "-extracted" + suffix)
                        do { try FileManager.default.moveItem(at: temporary, to: destination); completed.append(destination); break }
                        catch {
                            guard FileManager.default.fileExists(atPath: destination.path) else { throw error }
                            index += 1
                        }
                    }
                    continue
                }
                let target: FormatID = action == .archive ? .zip : format
                let temporary = OutputNamer.makeTemporaryOutput(for: target, in: directory)
                defer { try? FileManager.default.removeItem(at: temporary) }
                if action == .archive {
                    guard let ditto = dependencies.path(for: "ditto") else { throw ConversionEngineError.missingDependency("ditto") }
                    try ProcessRunner.run(.init(executable: ditto, arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", input.path, temporary.path]))
                } else if format.kind == .image {
                    guard let magick = dependencies.path(for: "magick") else { throw ConversionEngineError.missingDependency("magick") }
                    var args = [input.path]
                    switch action {
                    case .resizeImage: args += ["-resize", "1920x1920>"]
                    case .rotate: args += ["-rotate", "90"]
                    case .stripMetadata: args += ["-strip"]
                    case .compress: args += ["-quality", "75"]
                    default: throw ConversionEngineError.unsupportedTarget(format)
                    }
                    args.append(temporary.path)
                    try ProcessRunner.run(.init(executable: magick, arguments: args))
                } else if format.kind == .video || format.kind == .audio {
                    guard let ffmpeg = dependencies.path(for: "ffmpeg") else { throw ConversionEngineError.missingDependency("ffmpeg") }
                    let invocation: ProcessInvocation
                    if action == .stripMetadata {
                        invocation = .init(executable: ffmpeg, arguments: ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path, "-map_metadata", "-1", "-c", "copy", temporary.path])
                    } else if action == .compress {
                        invocation = FFmpegAdapter.invocation(input: input, output: temporary, target: format,
                            ffmpegPath: ffmpeg, options: .init(audioBitrateKbps: 128, videoPreset: "veryfast"))
                    } else { throw ConversionEngineError.unsupportedTarget(format) }
                    try ProcessRunner.run(invocation)
                } else { throw ConversionEngineError.unsupportedTarget(format) }
                guard FileManager.default.fileExists(atPath: temporary.path) else { throw ConversionEngineError.outputMissing(temporary) }
                completed.append(try OutputNamer.commitTemporaryOutput(temporary, for: input, target: target, in: directory))
            }
            return completed
        } catch {
            for output in completed { try? FileManager.default.removeItem(at: output) }
            throw error
        }
    }
}
