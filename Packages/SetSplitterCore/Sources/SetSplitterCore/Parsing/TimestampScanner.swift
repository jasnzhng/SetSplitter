//
//  TimestampScanner.swift
//  SetSplitterCore
//
//  implementation.md §5.1. Stage 1 of the pipeline. URLs are stripped first so
//  a `&t=156s` query parameter can't be mistaken for a timestamp, and a
//  markdown link `[0:00](url)` keeps only its label. What's left is scanned for
//  `mm:ss` / `h:mm:ss` tokens with word-ish boundaries (`2:00PM` is rejected).
//  Each timestamp starts one `RawSegment`; the segment text is everything up to
//  the next timestamp. The scanner never depends on newlines.
//

import Foundation

/// A timestamp plus the raw text that follows it, up to the next timestamp.
/// Cleaning and artist/title splitting happen in later stages.
struct RawSegment: Equatable {
    let start: Timestamp
    /// Text after the timestamp (and its markdown link, if any), verbatim.
    let text: String
}

/// Stage 1: find timestamps, yield raw segments. Pure; instantiated per parse.
struct TimestampScanner {

    /// `(?:\d{1,2}:)?\d{1,2}:\d{2}` — optional hour field, then mm:ss.
    private let timestampPattern = /(?:\d{1,2}:)?\d{1,2}:\d{2}/

    /// `[label](url)` — markdown link.
    private let markdownLinkPattern = /\[([^\]\n]*)\]\(([^)\n]*)\)/

    /// `http://…` / `https://…` / `www.…` up to the next whitespace.
    private let bareURLPattern = /(?:https?:\/\/|www\.)\S+/

    /// Scans `text`, returning one `RawSegment` per timestamp in document order.
    /// Text before the first timestamp is discarded (it addresses no track).
    func scan(_ text: String) -> [RawSegment] {
        let cleaned = stripURLs(from: text)
        let chars = Array(cleaned)

        // Accepted timestamp matches, as character offsets into `cleaned`.
        var hits: [(matchStart: Int, matchEnd: Int, start: Timestamp)] = []
        for match in cleaned.matches(of: timestampPattern) {
            let lower = cleaned.distance(from: cleaned.startIndex, to: match.range.lowerBound)
            let upper = cleaned.distance(from: cleaned.startIndex, to: match.range.upperBound)
            guard hasWordishBoundaries(chars, start: lower, end: upper) else { continue }
            guard let ts = Timestamp(text: String(match.output)) else { continue }
            hits.append((lower, upper, ts))
        }

        guard !hits.isEmpty else { return [] }

        var segments: [RawSegment] = []
        for (i, hit) in hits.enumerated() {
            let textStart = hit.matchEnd
            let textEnd = (i + 1 < hits.count) ? hits[i + 1].matchStart : chars.count
            segments.append(RawSegment(start: hit.start, text: String(chars[textStart..<textEnd])))
        }
        return segments
    }

    // MARK: - Helpers

    /// Replaces markdown links with their label, then removes bare URLs. Done
    /// before scanning so URL query strings can't leak timestamp-shaped tokens.
    private func stripURLs(from text: String) -> String {
        let delinked = text.replacing(markdownLinkPattern) { match in
            " \(match.output.1) "
        }
        return delinked.replacing(bareURLPattern, with: " ")
    }

    /// A timestamp token must not butt up against a letter or digit: `2:00PM`
    /// and `v1:23` are rejected, `[0:00]` and ` 4:44 ` are accepted.
    private func hasWordishBoundaries(_ chars: [Character], start: Int, end: Int) -> Bool {
        if start > 0 {
            let before = chars[start - 1]
            if before.isLetter || before.isNumber { return false }
        }
        if end < chars.count {
            let after = chars[end]
            if after.isLetter || after.isNumber { return false }
        }
        return true
    }
}
