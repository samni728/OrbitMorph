import Foundation

private final class SVGReadCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Bool] = [:]

    func lookup(_ path: String) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        return values[path]
    }

    func save(_ value: Bool, for path: String) {
        lock.lock(); defer { lock.unlock() }
        values[path] = value
    }
}

public enum ImageMagickAdapter {
    private static let svgReadCache = SVGReadCache()

    public static func canReadSVG(magickPath: String) -> Bool {
        if let cached = svgReadCache.lookup(magickPath) { return cached }
        let fixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrbitMorph-SVGProbe-\(UUID().uuidString).svg")
        defer { try? FileManager.default.removeItem(at: fixture) }
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"2\" height=\"2\"><rect width=\"2\" height=\"2\" fill=\"red\"/></svg>"
        let available = (try? svg.write(to: fixture, atomically: true, encoding: .utf8)) != nil &&
            (try? ProcessRunner.run(.init(executable: magickPath, arguments: [fixture.path, "-resize", "1x1", "null:"]), timeout: 10)) != nil
        svgReadCache.save(available, for: magickPath)
        return available
    }

    public static func invocation(
        input: URL,
        output: URL,
        target: FormatID,
        magickPath: String,
        options: FormatDefaults = .init()
    ) -> ProcessInvocation {
        let imageInput = (target == .gif || target == .pdf) ? input.path : input.path + "[0]"
        var args = [imageInput]
        if !options.preserveMetadata { args.append("-strip") }
        if let quality = options.quality, [.jpg, .webp, .heic, .avif].contains(target) {
            args += ["-quality", String(Int((min(1, max(0, quality)) * 100).rounded()))]
        } else if target == .jpg {
            args += ["-quality", "92"]
        } else if target == .webp {
            args += ["-quality", "88"]
        }
        args.append(output.path)
        return .init(executable: magickPath, arguments: args)
    }
}
