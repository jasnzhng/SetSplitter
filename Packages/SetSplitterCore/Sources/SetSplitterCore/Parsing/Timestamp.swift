//
//  Timestamp.swift
//  SetSplitterCore
//
//  implementation.md §4, §5.1. A position in the source audio, in seconds.
//  Two-segment timestamps are always mm:ss (never h:mm); three-segment are
//  h:mm:ss. The parser is timestamp-anchored: every Timestamp the scanner
//  emits becomes the start of exactly one track.
//

import Foundation

/// A position within the source audio, measured in seconds from the start.
///
/// Created either directly (`Timestamp(seconds:)`) or by parsing a `mm:ss` /
/// `h:mm:ss` string (`Timestamp(text:)`). Comparison and equality are on the
/// raw second value.
public struct Timestamp: Hashable, Sendable, Comparable {

    /// Seconds from the start of the source. Always `>= 0` for parsed values.
    public let seconds: Double

    public init(seconds: Double) {
        self.seconds = seconds
    }

    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        lhs.seconds < rhs.seconds
    }
}

// MARK: - String parsing

public extension Timestamp {

    /// Parses `mm:ss` or `h:mm:ss` (or `hh:mm:ss`). Returns `nil` when the shape
    /// doesn't match or a minutes/seconds field is `>= 60`.
    ///
    /// - `"4:44"`   → 284 s   (mm:ss — the leading field is minutes, never hours)
    /// - `"1:02:03"` → 3723 s (h:mm:ss)
    /// - `"75:00"`  → 4500 s  (minutes may exceed 59 in the two-segment form)
    init?(text: some StringProtocol) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count) else { return nil }

        var values: [Int] = []
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber), let n = Int(trimmed) else {
                return nil
            }
            values.append(n)
        }
        // Absurd fields would overflow the arithmetic below; no real set is this long.
        guard values.allSatisfy({ $0 < 100_000 }) else { return nil }

        let hours: Int
        let minutes: Int
        let secs: Int
        if values.count == 3 {
            (hours, minutes, secs) = (values[0], values[1], values[2])
            guard minutes < 60 else { return nil }
        } else {
            (hours, minutes, secs) = (0, values[0], values[1])
        }
        guard secs < 60 else { return nil }

        self.init(seconds: Double(hours * 3600 + minutes * 60 + secs))
    }
}

// MARK: - Display

public extension Timestamp {

    /// `h:mm:ss` when at least an hour, otherwise `m:ss`. Used for preview cards
    /// and warning messages, not for tags.
    var displayString: String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
