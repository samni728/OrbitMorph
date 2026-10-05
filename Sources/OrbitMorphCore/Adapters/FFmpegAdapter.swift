import Foundation

private final class FFmpegEncoderCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]
    private var workingFormats: [String: Bool] = [:]

    func lookup(_ path: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return values[path]
    }

    func save(_ encoder: String?, for path: String) {
        lock.lock(); defer { lock.unlock() }
        values[path] = encoder ?? ""
    }

    func working(_ key: String) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        return workingFormats[key]
    }

    func saveWorking(_ value: Bool, for key: String) {
        lock.lock(); defer { lock.unlock() }
        workingFormats[key] = value
    }
}

public enum FFmpegAdapter {
    private static let encoderCache = FFmpegEncoderCache()

    public static func canEncodeWMV(ffmpegPath: String, ffprobePath: String? = DependencyResolver().path(for: "ffprobe")) -> Bool {
        probe(ffmpegPath: ffmpegPath, ffprobePath: ffprobePath, format: .wmv)
    }
    public static func canEncodeWMA(ffmpegPath: String, ffprobePath: String? = DependencyResolver().path(for: "ffprobe")) -> Bool {
        probe(ffmpegPath: ffmpegPath, ffprobePath: ffprobePath, format: .wma)
    }

    public static func canEncodeExtended(_ format: FormatID, ffmpegPath: String, ffprobePath: String? = DependencyResolver().path(for: "ffprobe")) -> Bool {
        guard [.flv, .ts, .threeGP, .caf].contains(format) else { return false }
        return probe(ffmpegPath: ffmpegPath, ffprobePath: ffprobePath, format: format)
    }

    private static func extendedArguments(_ target: FormatID, bitrate: String, preset: String, quality: Double? = nil) -> [String] {
        let qualityArguments: [String]
        if let quality {
            qualityArguments = target == .flv ? ["-q:v", String(Int((15 - quality * 13).rounded()))] :
                ["-crf", String(Int((35 - quality * 17).rounded()))]
        } else { qualityArguments = [] }
        switch target {
        case .flv: return ["-c:v", "flv1"] + qualityArguments + ["-c:a", "aac", "-ar", "44100", "-b:a", bitrate, "-f", "flv"]
        case .ts: return ["-c:v", "libx264", "-preset", preset, "-pix_fmt", "yuv420p"] + qualityArguments + ["-c:a", "aac", "-b:a", bitrate, "-f", "mpegts"]
        case .threeGP: return ["-c:v", "libx264", "-preset", preset, "-pix_fmt", "yuv420p"] + qualityArguments + ["-c:a", "aac", "-ar", "44100", "-ac", "2", "-b:a", bitrate, "-f", "3gp"]
        case .caf: return ["-vn", "-c:a", "pcm_s16le", "-f", "caf"]
        default: return []
        }
    }

    private static func probe(ffmpegPath: String, ffprobePath: String?, format: FormatID) -> Bool {
        guard let ffprobePath, FileManager.default.isExecutableFile(atPath: ffprobePath) else { return false }
        func identity(_ path: String) -> String {
            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            return "\(path)|\(attributes?[.size] ?? 0)|\(attributes?[.modificationDate] ?? Date.distantPast)"
        }
        let key = "\(identity(ffmpegPath))|\(identity(ffprobePath))|\(format.rawValue)"
        if let cached = encoderCache.working(key) { return cached }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrbitMorph-CodecProbe-\(UUID().uuidString).\(format.fileExtension)")
        defer { try? FileManager.default.removeItem(at: output) }
        var args = ["-hide_banner", "-loglevel", "error", "-y"]
        if format == .wmv || format.kind == .video {
            args += ["-f", "lavfi", "-i", "color=c=black:s=32x32:d=0.1",
                     "-f", "lavfi", "-i", "sine=frequency=600:duration=0.1"]
            args += format == .wmv ? ["-c:v", "wmv2", "-c:a", "wmav2"] : extendedArguments(format, bitrate: "192k", preset: "veryfast")
            args.append("-shortest")
        } else {
            args += ["-f", "lavfi", "-i", "sine=frequency=600:duration=0.1"]
            args += format == .wma ? ["-c:a", "wmav2"] : extendedArguments(format, bitrate: "192k", preset: "veryfast")
        }
        args.append(output.path)
        let succeeded = (try? ProcessRunner.run(.init(executable: ffmpegPath, arguments: args), timeout: 10)) != nil
        let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0
        struct Probe: Decodable { struct Stream: Decodable { let codec_type: String }; let streams: [Stream] }
        let inspection = succeeded && size > 0 ? try? ProcessRunner.run(.init(executable: ffprobePath,
            arguments: ["-v", "error", "-show_entries", "stream=codec_type", "-of", "json", output.path]), timeout: 10).output : nil
        let streams = inspection.flatMap { try? JSONDecoder().decode(Probe.self, from: Data($0.utf8)) }
        let types = Set(streams?.streams.map(\.codec_type) ?? [])
        let available = types.contains("audio") && (format.kind != .video || types.contains("video"))
        encoderCache.saveWorking(available, for: key)
        return available
    }

    public static func vorbisEncoder(ffmpegPath: String) -> String? {
        if let cached = encoderCache.lookup(ffmpegPath) { return cached.isEmpty ? nil : cached }
        let output = try? ProcessRunner.run(
            .init(executable: ffmpegPath, arguments: ["-hide_banner", "-encoders"]), timeout: 10
        ).output
        let encoders = Set((output ?? "").components(separatedBy: .newlines).compactMap { line -> String? in
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2, parts[0].first == "A" else { return nil }
            return String(parts[1])
        })
        let encoder = encoders.contains("libvorbis") ? "libvorbis" : encoders.contains("vorbis") ? "vorbis" : nil
        encoderCache.save(encoder, for: ffmpegPath)
        return encoder
    }

    public static func invocation(
        input: URL,
        output: URL,
        target: FormatID,
        ffmpegPath: String,
        options: FormatDefaults = .init()
    ) -> ProcessInvocation {
        var args = ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path]
        if !options.preserveMetadata { args += ["-map_metadata", "-1"] }
        let bitrate = "\(max(32, min(512, options.audioBitrateKbps ?? 192)))k"
        let presets: Set<String> = ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"]
        let preset = options.videoPreset.flatMap { presets.contains($0) ? $0 : nil } ?? "veryfast"
        let quality = options.quality.map { min(1, max(0, $0)) }
        switch target {
        case .flv, .ts, .threeGP, .caf:
            args += extendedArguments(target, bitrate: bitrate, preset: preset, quality: quality)
        case .mp3:
            args += ["-vn", "-c:a", "libmp3lame", "-b:a", bitrate]
        case .m4a, .aac:
            args += ["-vn", "-c:a", "aac", "-b:a", bitrate]
        case .wav:
            args += ["-vn", "-c:a", "pcm_s16le"]
        case .flac:
            args += ["-vn", "-c:a", "flac"]
        case .ogg:
            let encoder = vorbisEncoder(ffmpegPath: ffmpegPath) ?? "vorbis"
            args += ["-vn", "-c:a", encoder]
            if encoder == "vorbis" { args += ["-strict", "-2", "-ac", "2"] }
            if options.audioBitrateKbps != nil {
                args += ["-b:a", bitrate]
            } else {
                args += ["-q:a", "5"]
            }
        case .opus:
            args += ["-vn", "-c:a", "libopus", "-b:a", bitrate]
        case .aiff:
            args += ["-vn", "-c:a", "pcm_s16be"]
        case .wma:
            args += ["-vn", "-c:a", "wmav2", "-b:a", bitrate]
        case .mp4, .m4v, .mov, .mkv:
            args += ["-c:v", "libx264", "-preset", preset, "-c:a", "aac", "-b:a", bitrate]
            if let quality { args += ["-crf", String(Int((35 - quality * 17).rounded()))] }
            if target == .mp4 || target == .m4v { args += ["-movflags", "+faststart"] }
        case .webm:
            args += ["-c:v", "libvpx-vp9", "-crf", String(Int((45 - (quality ?? 0.76) * 17).rounded())), "-b:v", "0", "-c:a", "libopus", "-b:a", bitrate]
        case .avi:
            args += ["-c:v", "mpeg4", "-q:v", String(Int((15 - (quality ?? 0.7) * 13).rounded())), "-c:a", "libmp3lame", "-b:a", bitrate]
        case .wmv:
            args += ["-c:v", "wmv2", "-c:a", "wmav2", "-b:a", bitrate]
            if let quality { args += ["-q:v", String(Int((15 - quality * 13).rounded()))] }
        case .gif:
            args += ["-vf", "fps=15,scale=640:-1:flags=lanczos"]
        default:
            break
        }
        args.append(output.path)
        return .init(executable: ffmpegPath, arguments: args)
    }
}
