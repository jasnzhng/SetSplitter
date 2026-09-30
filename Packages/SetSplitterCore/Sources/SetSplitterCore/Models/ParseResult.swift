//
//  ParseResult.swift
//  SetSplitterCore
//

import Foundation

/// The full result of parsing one tracklist.
public struct ParseResult: Sendable {

    /// Tracks in tracklist order, `index` 1-based and contiguous.
    public var tracks: [ParsedTrack]

    /// Document-level warnings (no timestamps, duplicates, first not 0:00, …).
    /// Track-level warnings live on each `ParsedTrack.warnings`.
    public var warnings: [ParseWarning]

    public init(tracks: [ParsedTrack] = [], warnings: [ParseWarning] = []) {
        self.tracks = tracks
        self.warnings = warnings
    }

    /// Every warning, document- and track-level, in document-then-track order.
    /// Convenience for the UI's flat warnings list.
    public var allWarnings: [ParseWarning] {
        warnings + tracks.flatMap(\.warnings)
    }
}
