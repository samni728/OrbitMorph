import AppKit
import PDFKit
import OrbitMorphCore

@MainActor
final class JobCoordinator {
    private let dependencies = DependencyResolver()

    func perform(item: WheelDisplayItem, files: [URL]) {
        let dependencies = self.dependencies
        Task {
            do {
                let outputs = try await Task.detached(priority: .userInitiated) { () -> [URL] in
                    switch item.value {
                    case .format(let target):
                        return try ConversionEngine(dependencies: dependencies).convert(.init(inputs: files, target: target)).map(\.outputURL)
                    case .tool(let action):
                        return try ToolExecutor.perform(action, files: files, dependencies: dependencies)
                    }
                }.value
                NSSound(named: .init("Glass"))?.play()
                print("ORBITMORPH job=success outputs=\(outputs.map(\.path))")
            } catch {
                NSSound.beep()
                print("ORBITMORPH job=failed error=\(error.localizedDescription)")
            }
        }
    }
}

enum ToolExecutor {
    static func perform(_ action: ToolActionID, files: [URL], dependencies: DependencyResolver) throws -> [URL] {
        switch action {
        case .extractAudio:
            return try ConversionEngine(dependencies: dependencies).convert(.init(inputs: files, target: .mp3)).map(\.outputURL)
        case .makeGIF:
            return try ConversionEngine(dependencies: dependencies).convert(.init(inputs: files, target: .gif)).map(\.outputURL)
        case .archive:
            guard let ditto = dependencies.path(for: "ditto") else { throw ConversionEngineError.missingDependency("ditto") }
            return try files.map { input in
                let output = OutputNamer.outputURL(for: input, target: .zip, in: input.deletingLastPathComponent())
                try ProcessRunner.run(.init(executable: ditto, arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", input.path, output.path]))
                return output
            }
        case .unarchive:
            guard let seven = dependencies.path(for: "7zz") else { throw ConversionEngineError.missingDependency("7zz") }
            return try files.map { input in
                let output = input.deletingPathExtension().appendingPathExtension("extracted")
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                try ProcessRunner.run(.init(executable: seven, arguments: ["x", "-y", "-o\(output.path)", input.path]))
                return output
            }
        case .resizeImage, .rotate, .stripMetadata, .compress:
            return try files.map { input in
                guard let format = FormatID(extension: input.pathExtension) else { throw ConversionEngineError.unknownFormat(input) }
                let output = OutputNamer.outputURL(for: input, target: format, in: input.deletingLastPathComponent())
                if format.kind == .image, let magick = dependencies.path(for: "magick") {
                    var args = [input.path]
                    switch action {
                    case .resizeImage: args += ["-resize", "1920x1920>"]
                    case .rotate: args += ["-rotate", "90"]
                    case .stripMetadata: args += ["-strip"]
                    case .compress: args += ["-quality", "75"]
                    default: break
                    }
                    args.append(output.path); try ProcessRunner.run(.init(executable: magick, arguments: args)); return output
                }
                if (format.kind == .video || format.kind == .audio), let ffmpeg = dependencies.path(for: "ffmpeg") {
                    var args = ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path]
                    if action == .stripMetadata { args += ["-map_metadata", "-1", "-c", "copy"] }
                    else if action == .compress && format.kind == .video { args += ["-c:v", "libx264", "-crf", "28", "-preset", "veryfast", "-c:a", "aac", "-b:a", "128k"] }
                    else if action == .compress { args += ["-b:a", "128k"] }
                    else { throw ConversionEngineError.unsupportedTarget(format) }
                    args.append(output.path); try ProcessRunner.run(.init(executable: ffmpeg, arguments: args)); return output
                }
                throw ConversionEngineError.unsupportedTarget(format)
            }
        case .pdfMerge:
            guard files.count > 1 else { return [] }
            let destination = files[0].deletingLastPathComponent().appendingPathComponent("Merged-converted.pdf")
            let result = PDFDocument()
            var pageIndex = 0
            for file in files {
                guard let doc = PDFDocument(url: file) else { continue }
                for i in 0..<doc.pageCount where doc.page(at: i) != nil {
                    result.insert(doc.page(at: i)!, at: pageIndex); pageIndex += 1
                }
            }
            guard result.write(to: destination) else { throw ConversionEngineError.outputMissing(destination) }
            return [destination]
        }
    }
}
