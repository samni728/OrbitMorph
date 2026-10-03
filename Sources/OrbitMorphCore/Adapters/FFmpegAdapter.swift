import Foundation

public enum FFmpegAdapter {
    public static func invocation(input: URL, output: URL, target: FormatID, ffmpegPath: String) -> ProcessInvocation {
        var args = ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path]
        switch target {
        case .mp3:
            args += ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
        case .m4a, .aac:
            args += ["-vn", "-c:a", "aac", "-b:a", "192k"]
        case .wav:
            args += ["-vn", "-c:a", "pcm_s16le"]
        case .flac:
            args += ["-vn", "-c:a", "flac"]
        case .ogg:
            args += ["-vn", "-c:a", "libvorbis", "-q:a", "5"]
        case .opus:
            args += ["-vn", "-c:a", "libopus", "-b:a", "160k"]
        case .aiff:
            args += ["-vn", "-c:a", "pcm_s16be"]
        case .mp4, .m4v:
            args += ["-c:v", "libx264", "-preset", "veryfast", "-c:a", "aac", "-movflags", "+faststart"]
        case .mov:
            args += ["-c:v", "libx264", "-preset", "veryfast", "-c:a", "aac"]
        case .mkv:
            args += ["-c:v", "libx264", "-preset", "veryfast", "-c:a", "aac"]
        case .webm:
            args += ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"]
        case .avi:
            args += ["-c:v", "mpeg4", "-q:v", "5", "-c:a", "libmp3lame"]
        case .gif:
            args += ["-vf", "fps=15,scale=640:-1:flags=lanczos"]
        default:
            break
        }
        args.append(output.path)
        return .init(executable: ffmpegPath, arguments: args)
    }
}
