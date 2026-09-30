//
//  PlannedTrack.swift
//  SetSplitterCore
//
//  implementation.md §4. A ParsedTrack resolved to a concrete sample-frame
//  range, a track number and a filename — the ExportPlanner's output.
//

import Foundation

/// A track ready to be cut from the source.
public struct PlannedTrack: Sendable, Identifiable {

    public var id: UUID { track.id }

    public let track: ParsedTrack

    /// Source sample frames: `lowerBound` inclusive, `upperBound` exclusive.
    public let range: Range<Int64>

    /// 1-based, contiguous, in playback order.
    public let trackNumber: Int

    /// Final file name, extension included, unique within the plan.
    public let filename: String

    public init(track: ParsedTrack, range: Range<Int64>, trackNumber: Int, filename: String) {
        self.track = track
        self.range = range
        self.trackNumber = trackNumber
        self.filename = filename
    }

    /// Title written to the tag; never empty.
    public var displayTitle: String {
        let t = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Track \(trackNumber)" : t
    }

    /// Track artist for the tag; empty when the parser found none (the
    /// `MetadataBuilder` then falls back to the album artist).
    public var displayArtist: String {
        track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
