//
//  LyricsParser.swift
//  PepBox
//
//  Parses time-synced LRC lyrics ("[01:23.45] line"). No app dependencies,
//  so scripts/logic-tests compiles it directly.
//

import Foundation

struct SyncedLyrics: Equatable {
    struct Line: Equatable {
        let time: TimeInterval
        let text: String
    }

    let lines: [Line]

    /// Parses LRC text. Lines can carry several timestamps ("[00:10.00][01:20.00] chorus");
    /// metadata tags like "[ar:Artist]" are skipped. Lines come out sorted by time.
    init(lrc: String) {
        var parsed: [Line] = []
        let stamp = try! NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{1,2}(?:[.:]\d{1,3})?)\]"#)
        for raw in lrc.components(separatedBy: .newlines) {
            let range = NSRange(raw.startIndex..., in: raw)
            let matches = stamp.matches(in: raw, range: range)
            guard !matches.isEmpty, let last = matches.last,
                  let textStart = Range(last.range, in: raw)?.upperBound else { continue }
            let text = raw[textStart...].trimmingCharacters(in: .whitespaces)
            for match in matches {
                guard let minutes = Range(match.range(at: 1), in: raw).flatMap({ Double(raw[$0]) }),
                      let secondsText = Range(match.range(at: 2), in: raw).map({ raw[$0].replacingOccurrences(of: ":", with: ".") }),
                      let seconds = Double(secondsText) else { continue }
                parsed.append(Line(time: minutes * 60 + seconds, text: text))
            }
        }
        lines = parsed.sorted { $0.time < $1.time }
    }

    /// The line being sung at `time`: the last one that has started. Nil before the first
    /// line and for instrumental gaps (empty lines).
    func line(at time: TimeInterval) -> String? {
        var low = 0, high = lines.count - 1, found = -1
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= time { found = mid; low = mid + 1 } else { high = mid - 1 }
        }
        guard found >= 0 else { return nil }
        let text = lines[found].text
        return text.isEmpty ? nil : text
    }
}
