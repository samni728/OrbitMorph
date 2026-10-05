import Foundation
import ImageIO
import UniformTypeIdentifiers

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

    /// The extra coders are optional in ImageMagick builds. Verify real write + read, then cache.
    public static func canRoundTrip(_ format: FormatID, magickPath: String) -> Bool {
        let key = "\(magickPath)|\(format.rawValue)"
        if let value = svgReadCache.lookup(key) { return value }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitMorph-ImageProbe-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        var available = false
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let png = root.appendingPathComponent("seed.png")
            guard let context = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let image = context.makeImage(),
                  let destination = CGImageDestinationCreateWithURL(png as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return false }
            let encoded = root.appendingPathComponent("encoded.\(format.fileExtension)")
            let decoded = root.appendingPathComponent("decoded.png")
            try ProcessRunner.run(.init(executable: magickPath, arguments: [png.path, encoded.path]), timeout: 15)
            try ProcessRunner.run(.init(executable: magickPath, arguments: [encoded.path + "[0]", decoded.path]), timeout: 15)
            if let source = CGImageSourceCreateWithURL(decoded as CFURL, nil), let result = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                available = result.width == 2 && result.height == 2
            }
        } catch { available = false }
        svgReadCache.save(available, for: key)
        return available
    }

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
        let isPSD = FormatID(fileURL: input) == .psd
        let imageInput = !isPSD && (target == .gif || target == .pdf) ? input.path : input.path + "[0]"
        var args = [imageInput]
        if target == .ico { args += ["-resize", "256x256>"] }
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
