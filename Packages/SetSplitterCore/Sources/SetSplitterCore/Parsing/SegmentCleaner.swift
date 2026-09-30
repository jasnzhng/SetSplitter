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
    private let leadingNumberDash = /^\s*\d{1,3}\s*[-–—]\s+/          // "1 - " (guarded, see `stripNumberDash`)

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
            s = stripNumberDash(from: s)
            s = s.replacing(leadingLeaders, with: "")
            s = s.trimmingCharacters(in: .whitespaces)
            changed = (s != before)
        }

        s = stripTrailingNumber(from: s)

        if options.stripBracketedTags {
            s = stripNoiseTags(from: s)
        }

        s = s.replacing(whitespaceRun, with: " ").trimmingCharacters(in: .whitespaces)
        return s
    }

    // MARK: - Helpers

    /// Strips a leading `"1 - "` only when what follows still looks like a full
    /// `Artist - Title` entry. Otherwise the number *is* the artist ("311 - Amber",
    /// "112 - Cupid") and must survive.
    private func stripNumberDash(from text: String) -> String {
        guard let match = text.firstMatch(of: leadingNumberDash) else { return text }
        let rest = String(text[match.range.upperBound...])
        let hasOwnSeparator = SeparatorTable.artistTitleSeparators.contains { rest.contains($0) }
        return hasOwnSeparator ? rest : text
    }

    /// Strips the next entry's dangling numbering (`"… (Intro Edit) 02."`), but not
    /// a number that closes a bracket the title opened (`"Song (Vol 2)"`).
    private func stripTrailingNumber(from text: String) -> String {
        guard let match = text.firstMatch(of: trailingNumber) else { return text }
        let prefix = text[..<match.range.lowerBound]
        return hasUnclosedBracket(prefix) ? text : String(prefix)
    }

    private func hasUnclosedBracket(_ text: Substring) -> Bool {
        var depth = 0
        for ch in text {
            if "([".contains(ch) { depth += 1 } else if ")]".contains(ch) { depth = max(0, depth - 1) }
        }
        return depth > 0
    }

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
