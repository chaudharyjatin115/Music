//
//  LRCParser.swift
//  YT Music
//

import Foundation

/// Parses LRC-formatted synced lyrics (`[mm:ss.xx] text`) into timed lines.
nonisolated enum LRCParser {
    /// Multi-timestamp lines expand to one entry each; metadata tags and untimed lines are dropped.
    /// Blank timed lines are kept as breathing room.
    static func parse(_ lrc: String) -> [LyricLine] {
        var offsetSeconds: Double = 0
        var rawLines: [(time: Double, text: String)] = []

        let tagPattern = #"\[([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return [] }

        for rawLine in lrc.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            guard !matches.isEmpty else { continue }

            var stamps: [Double] = []
            var lastTagEnd = 0

            for match in matches {
                guard match.numberOfRanges > 1 else { continue }
                let tagContent = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if tagContent.lowercased().hasPrefix("offset:") {
                    let val = tagContent.dropFirst(7).trimmingCharacters(in: .whitespaces)
                    if let ms = Double(val) {
                        offsetSeconds = ms / 1000.0
                    }
                } else if let sec = timestamp(tagContent) {
                    stamps.append(sec)
                    lastTagEnd = max(lastTagEnd, match.range.location + match.range.length)
                }
            }

            guard !stamps.isEmpty else { continue }
            let text = nsLine.substring(from: lastTagEnd).trimmingCharacters(in: .whitespaces)
            for stamp in stamps {
                rawLines.append((stamp, text))
            }
        }

        return rawLines
            .sorted { $0.time < $1.time }
            .enumerated()
            .map { idx, item in
                let adjustedTime = max(0, item.time - offsetSeconds)
                return LyricLine(time: adjustedTime, text: item.text, id: idx)
            }
    }

    private static func timestamp(_ body: String) -> Double? {
        let cleaned = body.replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.split(separator: ":")
        if parts.count == 2 {
            guard let minutes = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                  let seconds = Double(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
            return minutes * 60 + seconds
        } else if parts.count == 3 {
            guard let hours = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                  let minutes = Double(parts[1].trimmingCharacters(in: .whitespaces)),
                  let seconds = Double(parts[2].trimmingCharacters(in: .whitespaces)) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        }
        return nil
    }
}
