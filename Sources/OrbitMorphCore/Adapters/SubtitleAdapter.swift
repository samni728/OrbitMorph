import Foundation

public enum SubtitleError: LocalizedError {
    case invalidUTF8
    case invalidHeader
    case invalidCue(Int, String)
    case unsupportedBlock(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8: return "Subtitle is not valid UTF-8"
        case .invalidHeader: return "WebVTT must start with a WEBVTT header followed by a blank line"
        case .invalidCue(let index, let reason): return "Invalid subtitle cue \(index): \(reason)"
        case .unsupportedBlock(let index, let name): return "Unsupported WebVTT block \(index): \(name)"
        }
    }
}

public enum SubtitleAdapter {
    private struct Cue {
        let identifier: String?
        let start: Int
        let end: Int
        let lines: [String]
    }

    public static func convert(input: URL, output: URL, source: FormatID, target: FormatID) throws {
        guard (source == .srt && target == .vtt) || (source == .vtt && target == .srt) else {
            throw ConversionEngineError.unsupported(source, target)
        }
        let data = try Data(contentsOf: input)
        guard var text = String(data: data, encoding: .utf8) else { throw SubtitleError.invalidUTF8 }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var blocks: [[String]] = []
        var current: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.isEmpty {
                if !current.isEmpty { blocks.append(current); current = [] }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { blocks.append(current) }
        if source == .vtt {
            guard let header = blocks.first, let first = header.first,
                  first == "WEBVTT" || first.hasPrefix("WEBVTT "), header.count == 1 else {
                throw SubtitleError.invalidHeader
            }
            blocks.removeFirst()
        }
        var cues: [Cue] = []
        for (index, block) in blocks.enumerated() {
            guard let first = block.first else { continue }
            if source == .vtt {
                if first == "NOTE" || first.hasPrefix("NOTE ") { continue }
                if first == "STYLE" || first == "REGION" {
                    throw SubtitleError.unsupportedBlock(index + 1, first)
                }
            }
            let hasIdentifier = !first.contains("-->")
            let timingIndex = hasIdentifier ? 1 : 0
            guard block.indices.contains(timingIndex) else {
                throw SubtitleError.invalidCue(index + 1, "missing timing")
            }
            let identifier = hasIdentifier ? first : nil
            if let identifier, identifier.isEmpty || identifier.contains("-->") {
                throw SubtitleError.invalidCue(index + 1, "invalid identifier")
            }
            if source == .srt, identifier.flatMap(Int.init).map({ $0 > 0 }) != true {
                throw SubtitleError.invalidCue(index + 1, "SRT cue requires a positive numeric sequence")
            }
            let timing = block[timingIndex].components(separatedBy: "-->")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard timing.count == 2,
                  let start = parseTime(timing[0], format: source),
                  let end = parseTime(timing[1], format: source), end > start else {
                throw SubtitleError.invalidCue(index + 1, "invalid timestamp or cue settings")
            }
            let lines = Array(block.dropFirst(timingIndex + 1))
            guard !lines.isEmpty, lines.contains(where: { !$0.isEmpty }) else {
                throw SubtitleError.invalidCue(index + 1, "missing text")
            }
            guard !lines.contains(where: { $0.contains("-->") }) else {
                throw SubtitleError.invalidCue(index + 1, "timing arrow is not supported in cue text")
            }
            cues.append(Cue(identifier: identifier, start: start, end: end, lines: lines))
        }
        guard !cues.isEmpty else { throw SubtitleError.invalidCue(1, "no subtitle cues") }
        let rendered = cues.enumerated().map { index, cue in
            let identifier = target == .srt ? String(index + 1) : cue.identifier
            let timing = "\(formatTime(cue.start, format: target)) --> \(formatTime(cue.end, format: target))"
            return ([identifier].compactMap { $0 } + [timing] + cue.lines).joined(separator: "\n")
        }.joined(separator: "\n\n")
        let outputText = (target == .vtt ? "WEBVTT\n\n" : "") + rendered + "\n"
        try outputText.write(to: output, atomically: true, encoding: .utf8)
    }

    private static func parseTime(_ raw: String, format: FormatID) -> Int? {
        let separator = format == .srt ? "," : "."
        let pair = raw.components(separatedBy: separator)
        guard pair.count == 2, pair[1].count == 3, pair[1].allSatisfy(\.isNumber),
              let millis = Int(pair[1]) else { return nil }
        let fields = pair[0].components(separatedBy: ":")
        guard (format == .srt && fields.count == 3) || (format == .vtt && (fields.count == 2 || fields.count == 3)),
              fields.allSatisfy({ $0.count >= 2 && $0.allSatisfy(\.isNumber) }),
              let seconds = Int(fields[fields.count - 1]), seconds < 60,
              let minutes = Int(fields[fields.count - 2]), minutes < 60 else { return nil }
        let hours = fields.count == 3 ? Int(fields[0]) : 0
        guard let hours, hours >= 0, hours <= 99_999 else { return nil }
        return ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis
    }

    private static func formatTime(_ milliseconds: Int, format: FormatID) -> String {
        let hours = milliseconds / 3_600_000
        let minutes = milliseconds / 60_000 % 60
        let seconds = milliseconds / 1_000 % 60
        let millis = milliseconds % 1_000
        let separator = format == .srt ? "," : "."
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, seconds, separator, millis)
    }
}
