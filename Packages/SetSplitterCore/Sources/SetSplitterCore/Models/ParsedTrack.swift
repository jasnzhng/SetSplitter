//
//  Track.swift
//  SetSplitterCore
//
//  implementation.md §4. `ParsedTrack` is the parser's per-track output;
//  `ParseResult` bundles the tracks with document-level warnings. Durations
//  are always derived (`next.start - this.start`), never stored here.
//

import Foundation

/// One track produced by the tracklist parser.
///
/// `artists` and `titles` are the structured result — arrays, never joined —
/// so callers can render them however they like. `artist` / `title` are the
/// display and tag strings. A track is created by the parser; inline edits are
/// layered on top afterwards by `TrackEdits` (keyed by `start`), which also sets
/// `userEdited`.
public struct ParsedTrack: Hashable, Sendable, Identifiable {

    public let id: UUID

    /// 1-based position in tracklist order.
    public var index: Int

    /// Start position in the source audio. The only thing that creates a track.
    public var start: Timestamp

    /// Ordered, case-insensitively de-duplicated. Never contain a separator
    /// token. Duo names ("Mauro Picotto & Eftihios") are a single element.
    public var artists: [String]

    /// One entry per mashed-up song. Remix / edit / bootleg credits stay
    /// inside the title string verbatim.
    public var titles: [String]

    /// The segment exactly as pasted (post timestamp), kept for preview
    /// tooltips and debugging.
    public var rawText: String

    /// Track-level warnings (missing artist, empty title, short track, …).
    public var warnings: [ParseWarning]

    /// `true` when `TrackEdits` has overridden this track's artist or title.
    /// Always `false` straight out of the parser.
    public var userEdited: Bool

    public init(
        id: UUID = UUID(),
        index: Int,
        start: Timestamp,
        artists: [String],
        titles: [String],
        rawText: String,
        warnings: [ParseWarning] = [],
        userEdited: Bool = false
    ) {
        self.id = id
        self.index = index
        self.start = start
        self.artists = artists
        self.titles = titles
        self.rawText = rawText
        self.warnings = warnings
        self.userEdited = userEdited
    }

    /// Display / tag artist: `artists` joined with `" & "`. Empty when unknown.
    public var artist: String { artists.joined(separator: " & ") }

    /// Display / tag title: `titles` joined with `" / "`.
    public var title: String { titles.joined(separator: " / ") }
}
