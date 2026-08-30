//
//  CreditParser.swift
//  SetSplitterCore
//
//  implementation.md §5.4. Stage 4. Turns ONE entry string ("Artist - Title")
//  into structured `artists` and `titles` arrays. Every separator is only
//  recognised at paren/bracket depth 0, so "(John Summit & Maddix Edit)" and
//  "[HNTR Edit]" survive intact. Artist names are NEVER split on "&", "and" or
//  "," — duo names pass through whole. Counts of artists vs titles need not
//  match and a mismatch is never an error.
//

import Foundation

/// The structured credit for one entry.
struct Credit: Equatable {
    var artists: [String]
    var titles: [String]
    var warnings: [ParseWarning]
}

/// Stage 4: one entry → artists + titles. Pure; instantiated per parse.
struct CreditParser {

    private let splitter = DepthAwareSplitter()
    private let whitespaceRun = /\s+/

    /// Parses a single entry (already cleaned, already free of `W/` joins).
    func parse(_ entry: String, options: ParseOptions) -> Credit {
        let trimmedEntry = normalize(entry)
        guard !trimmedEntry.isEmpty else {
            return Credit(artists: [], titles: [], warnings: [.emptyTitle])
        }

        // (a) primary split into artist side / title side
        let candidates = primarySeparatorCandidates(options)
        guard let split = splitter.firstSplit(of: candidates, in: trimmedEntry, wholeWord: false) else {
            return Credit(artists: [], titles: [trimmedEntry], warnings: [.missingArtist])
        }

        let leftSide = normalize(split.head)
        let rightSide = normalize(split.tail)
        let artistSide: String
        let titleSide: String
        switch options.fieldOrder {
        case .artistThenTitle:
            artistSide = leftSide
            titleSide = rightSide
        case .titleThenArtist:
            artistSide = rightSide
            titleSide = leftSide
        }

        var warnings: [ParseWarning] = []

        // (b) split the artist side
        var artists = splitArtistSide(artistSide, options: options)
        if artists.isEmpty { warnings.append(.missingArtist) }

        // (c) split the title side on "vs." forms, then (d) pull featured credits
        var titles: [String] = []
        for subtitle in splitter.allComponents(splittingOn: SeparatorTable.titleSeparators, in: titleSide, wholeWord: true) {
            let (cleanedTitle, featured) = extractFeaturedCredits(from: normalize(subtitle))
            if !cleanedTitle.isEmpty { titles.append(cleanedTitle) }
            artists.append(contentsOf: featured)
        }
        if titles.isEmpty { warnings.append(.emptyTitle) }

        // (e) trim + dedupe artists case-insensitively, first occurrence wins
        artists = dedupe(artists.map(normalize).filter { !$0.isEmpty })

        return Credit(artists: artists, titles: titles, warnings: warnings)
    }

    // MARK: - (a) primary separator

    private func primarySeparatorCandidates(_ options: ParseOptions) -> [String] {
        switch options.separatorMode {
        case .auto:          return SeparatorTable.artistTitleSeparators
        case .hyphen:        return [" - "]
        case .enDash:        return [" – "]
        case .emDash:        return [" — "]
        case .colon:         return [" : ", ": "]
        case .slash:         return [" / ", "/"]
        case .custom(let s): return s.isEmpty ? SeparatorTable.artistTitleSeparators : [" \(s) ", s]
        }
    }

    // MARK: - (b) artist side

    private func splitArtistSide(_ side: String, options: ParseOptions) -> [String] {
        guard !side.isEmpty else { return [] }
        var tokens = SeparatorTable.artistSeparators
        if options.treatXAsArtistSeparator {
            tokens.append(SeparatorTable.optionalArtistSeparatorX)
        }
        return splitter
            .allComponents(splittingOn: tokens, in: side, wholeWord: true)
            .map(normalize)
            .filter { !$0.isEmpty }
    }

    // MARK: - (d) featured credits inside the title

    /// Removes any depth-0 `(feat. X)` / `[ft. X]` group from `title` and
    /// returns the cleaned title plus the extracted artist names. Remix / edit /
    /// bootleg / mashup parentheticals contain none of the feat markers and are
    /// left in place.
    private func extractFeaturedCredits(from title: String) -> (title: String, artists: [String]) {
        let chars = Array(title)
        let groups = topLevelBracketGroups(in: chars)
        guard !groups.isEmpty else { return (title, []) }

        var featured: [String] = []
        var dropRanges: [Range<Int>] = []
        for group in groups {
            let inner = String(chars[group.contentRange]).trimmingCharacters(in: .whitespaces)
            guard let name = featuredName(in: inner) else { continue }
            featured.append(name)
            dropRanges.append(group.fullRange)
        }
        guard !dropRanges.isEmpty else { return (title, []) }

        var kept = ""
        var i = 0
        while i < chars.count {
            if let r = dropRanges.first(where: { $0.lowerBound == i }) {
                i = r.upperBound
                continue
            }
            kept.append(chars[i])
            i += 1
        }
        let cleaned = kept.replacing(whitespaceRun, with: " ").trimmingCharacters(in: .whitespaces)
        return (cleaned, featured)
    }

    /// If `inner` begins with a feat marker, returns the trailing name(s) as a
    /// single string (not `&`-split, per the decision log). Otherwise `nil`.
    private func featuredName(in inner: String) -> String? {
        let lower = inner.lowercased()
        for marker in SeparatorTable.featuredCreditMarkers {
            let m = marker.lowercased()
            guard lower.hasPrefix(m) else { continue }
            let afterIdx = inner.index(inner.startIndex, offsetBy: marker.count)
            guard afterIdx < inner.endIndex else { continue }
            let next = inner[afterIdx]
            // marker must be followed by a separating space or "." then space
            guard next == " " || next == "." else { continue }
            let name = inner[afterIdx...].trimmingCharacters(in: CharacterSet(charactersIn: " ."))
            return name.isEmpty ? nil : name
        }
        return nil
    }

    // MARK: - depth-0 bracket groups

    private struct BracketGroup {
        let fullRange: Range<Int>     // includes the brackets
        let contentRange: Range<Int>  // between the brackets
    }

    private func topLevelBracketGroups(in chars: [Character]) -> [BracketGroup] {
        guard bracketsBalanced(chars) else { return [] }
        var groups: [BracketGroup] = []
        var depth = 0
        var openAt = -1
        for (i, c) in chars.enumerated() {
            if c == "(" || c == "[" {
                if depth == 0 { openAt = i }
                depth += 1
            } else if c == ")" || c == "]" {
                depth -= 1
                if depth == 0, openAt >= 0 {
                    groups.append(BracketGroup(fullRange: openAt..<(i + 1), contentRange: (openAt + 1)..<i))
                    openAt = -1
                }
            }
        }
        return groups
    }

    private func bracketsBalanced(_ chars: [Character]) -> Bool {
        var round = 0, square = 0
        for c in chars {
            switch c {
            case "(": round += 1
            case ")": round -= 1; if round < 0 { return false }
            case "[": square += 1
            case "]": square -= 1; if square < 0 { return false }
            default: break
            }
        }
        return round == 0 && square == 0
    }

    // MARK: - (e) helpers

    private func normalize(_ s: some StringProtocol) -> String {
        String(s).replacing(whitespaceRun, with: " ").trimmingCharacters(in: .whitespaces)
    }

    private func dedupe(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for n in names {
            let key = n.lowercased()
            if seen.insert(key).inserted { out.append(n) }
        }
        return out
    }
}
