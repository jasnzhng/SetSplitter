//
//  EntrySplitter.swift
//  SetSplitterCore
//
//  Stage 3. One timestamped segment may carry several
//  complete `Artist - Title` entries joined by an entry separator (`W/`, `w/`,
//  or `With` at a chunk start). Splitting these out BEFORE any artist/title
//  work is essential — a merged segment holds multiple " - " separators and
//  splitting on " - " first produces garbage.
//
//  A timestamp is still the only thing that creates a *track*; an entry
//  separator only creates another entry within the same track.
//

import Foundation

/// Stage 3: segment text → entry strings (all for one track). Pure.
struct EntrySplitter {

    private let splitter = DepthAwareSplitter()
    /// The spelled-out separator only counts when a `|` chunk leader follows it
    /// — otherwise "Song with Friends" would be torn apart.
    private let spelledWithBeforePipe = /\s+[Ww]ith\s+(?=\|)/

    /// Splits `segment` into entries. Always returns at least one; entries are
    /// left untrimmed of chunk leaders (the caller re-runs `SegmentCleaner`).
    func split(_ segment: String) -> [String] {
        let bySlash = splitter.allComponents(
            splittingOn: SeparatorTable.entrySeparators,
            in: segment,
            wholeWord: true
        )

        var entries: [String] = []
        for part in bySlash {
            let subParts = part.split(separator: spelledWithBeforePipe, omittingEmptySubsequences: false)
            entries.append(contentsOf: subParts.map(String.init))
        }

        let nonEmpty = entries
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return nonEmpty.isEmpty ? [segment] : nonEmpty
    }
}
