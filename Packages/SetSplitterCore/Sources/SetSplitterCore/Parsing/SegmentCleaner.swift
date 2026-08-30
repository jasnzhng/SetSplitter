//
//  SegmentCleaner.swift
//  SetSplitterCore
//
//  implementation.md §5.2. Stage 2. Takes one raw segment's text and strips
//  everything that isn't artist/title: leading track numbering and
//  pipe/dash/bullet leaders, the *next* entry's numbering that leaked onto the
//  end in a one-line list (`… (Intro Edit) 02.`), promotional bracketed tags
//  (gated by `ParseOptions.stripBracketedTags`), and redundant whitespace.
//
//  The rules are a list you can extend one line at a time. Input is assumed
//  already Unicode-normalised by `TracklistParser` (CRLF, NBSP, zero-width).
//

import Foundation

/// Stage 2: per-segment noise removal. Pure; instantiated per parse.
struct SegmentCleaner {

    // Leading noise, tried repeatedly until the string stops shrinking.
    private let leadingLeaders = /^[\s|•*>·‣–—-]+/
    private let leadingNumberDot = /^\s*#?\d{1,3}\s*[.)]\s+/          // "01. " "1) " "#3. "
    private let leadingBracketNumber = /^\s*\[\d{1,3}\]\s*/           // "[1] "
    private let leadingHashNumber = /^\s*#\d{1,3}\s+/                 // "#1 "
    private let leadingNumberDash = /^\s*\d{1,3}\s*[-–—]\s+/          // "1 - "

    // The next entry's numbering, left dangling on the end of a one-line list.
    private let trailingNumber = /\s*\b\d{1,3}\s*[.)]\s*$/

    private let bracketGroup = /[\[(]([^\[\]()]*)[\])]/

    private let whitespaceRun = /\s+/

    /// Cleans one segment. Never returns leading/trailing whitespace.
    func clean(_ text: String, options: ParseOptions) -> String {
        var s = text.replacing(whitespaceRun, with: " ").trimmingCharacters(in: .whitespaces)

        // Leading leaders + numbering, alternating until stable.
        var changed = true
        while changed {
            let before = s
            s = s.replacing(leadingNumberDot, with: "")
            s = s.replacing(leadingBracketNumber, with: "")
            s = s.replacing(leadingHashNumber, with: "")
            s = s.replacing(leadingNumberDash, with: "")
            s = s.replacing(leadingLeaders, with: "")
            s = s.trimmingCharacters(in: .whitespaces)
            changed = (s != before)
        }

        // Trailing numbering that belongs to the next entry.
        s = s.replacing(trailingNumber, with: "")

        if options.stripBracketedTags {
            s = stripNoiseTags(from: s)
        }

        s = s.replacing(whitespaceRun, with: " ").trimmingCharacters(in: .whitespaces)
        return s
    }

    // MARK: - Helpers

    /// Removes `[...]` / `(...)` groups whose contents are a known promo tag.
    /// Musical parentheticals ("(Eli Brown Remix)", "(Acappella)") are kept.
    private func stripNoiseTags(from text: String) -> String {
        text.replacing(bracketGroup) { match in
            let inner = String(match.output.1)
                .lowercased()
                .replacing(whitespaceRun, with: " ")
                .trimmingCharacters(in: .whitespaces)
            let isNoise = SeparatorTable.bracketedNoiseTags.contains { tag in
                inner == tag || inner.contains(tag)
            }
            return isNoise ? "" : String(match.output.0)
        }
    }
}
