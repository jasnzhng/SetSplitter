//
//  TrackAssembler.swift
//  SetSplitterCore
//
//  Stage 5. Merges the per-entry `Credit`s of one
//  timestamped segment into a single `ParsedTrack`. `mashupStrategy` decides
//  whether entries after the first are kept (`.merge`, default) or dropped
//  (`.firstEntryOnly`).
//

import Foundation

/// Stage 5: `[Credit]` for one timestamp → one `ParsedTrack`. Pure.
struct TrackAssembler {

    func assemble(
        index: Int,
        start: Timestamp,
        rawText: String,
        credits: [Credit],
        options: ParseOptions
    ) -> ParsedTrack {
        let used = options.mashupStrategy == .firstEntryOnly
            ? Array(credits.prefix(1))
            : credits

        var artists: [String] = []
        var titles: [String] = []
        for credit in used {
            artists.append(contentsOf: credit.artists)
            titles.append(contentsOf: credit.titles)
        }
        artists = TextHelpers.dedupedCaseInsensitively(artists)

        var warnings = Set<ParseWarning>()
        for credit in used {
            for warning in credit.warnings {
                // Re-derive artist/title warnings from the merged result below.
                if warning == .missingArtist || warning == .emptyTitle { continue }
                warnings.insert(warning)
            }
        }
        if artists.isEmpty { warnings.insert(.missingArtist) }
        if titles.isEmpty { warnings.insert(.emptyTitle) }

        return ParsedTrack(
            index: index,
            start: start,
            artists: artists,
            titles: titles,
            rawText: rawText,
            warnings: orderedWarnings(from: warnings)
        )
    }

    // MARK: - Helpers

    /// Deterministic order so tests and the UI list are stable.
    private func orderedWarnings(from set: Set<ParseWarning>) -> [ParseWarning] {
        let priority: [ParseWarning] = [.missingArtist, .emptyTitle, .timestampNotIncreasing, .trackShorterThanFiveSeconds]
        var out = priority.filter { set.contains($0) }
        out.append(contentsOf: set.subtracting(out).sorted { "\($0)" < "\($1)" })
        return out
    }
}
