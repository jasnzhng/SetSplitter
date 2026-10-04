//
//  TrackEdits.swift
//  SetSplitterCore
//
//  Inline edits on preview cards survive
//  re-parses as long as the edited track's timestamp still exists. Edits are
//  keyed by start time rather than track identity because every re-parse mints
//  new `ParsedTrack` ids.
//

import Foundation

/// The user's manual corrections, layered over parser output.
public struct TrackEdits: Sendable, Equatable {

    /// A correction to one track. `nil` means "leave the parsed value".
    public struct Override: Sendable, Equatable {
        public var artist: String?
        public var title: String?
    }

    private var byStart: [Timestamp: Override] = [:]

    public init() {}

    public var isEmpty: Bool { byStart.isEmpty }

    public func isEdited(_ track: ParsedTrack) -> Bool { byStart[track.start] != nil }

    /// Records a new artist for the track starting at `start`.
    public mutating func setArtist(_ artist: String, at start: Timestamp) {
        byStart[start, default: Override()].artist = artist
    }

    /// Records a new title for the track starting at `start`.
    public mutating func setTitle(_ title: String, at start: Timestamp) {
        byStart[start, default: Override()].title = title
    }

    /// Forgets the edits for one track, restoring the parsed values.
    public mutating func reset(at start: Timestamp) {
        byStart[start] = nil
    }

    public mutating func resetAll() {
        byStart.removeAll()
    }

    /// Returns `tracks` with overrides applied. An override whose timestamp no
    /// longer exists is simply ignored (and kept, so it returns if the user
    /// undoes whatever removed the timestamp).
    public func applying(to tracks: [ParsedTrack]) -> [ParsedTrack] {
        guard !byStart.isEmpty else { return tracks }
        return tracks.map { track in
            guard let edit = byStart[track.start] else { return track }
            var t = track
            t.userEdited = true
            if let artist = edit.artist {
                let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
                t.artists = trimmed.isEmpty ? [] : [trimmed]
                t.warnings.removeAll { $0 == .missingArtist }
            }
            if let title = edit.title {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                t.titles = trimmed.isEmpty ? [] : [trimmed]
                t.warnings.removeAll { $0 == .emptyTitle }
            }
            return t
        }
    }
}
