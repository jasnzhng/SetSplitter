//
//  ExportPlanner.swift
//  SetSplitterCore
//
//  implementation.md §7.2, §14. Resolves parsed tracks (timestamps) into
//  concrete, gapless frame ranges and unique filenames. Pure and deterministic.
//

import Foundation

/// The planner's output.
public struct ExportPlan: Sendable {

    public var tracks: [PlannedTrack]

    /// Document-level warnings the planner produced (e.g. dropped tracks).
    public var warnings: [ParseWarning]

    public init(tracks: [PlannedTrack], warnings: [ParseWarning] = []) {
        self.tracks = tracks
        self.warnings = warnings
    }

    /// `true` when the ranges are contiguous: each track starts exactly where
    /// the previous one ended, with no overlap and no gap.
    public var isContiguous: Bool {
        zip(tracks, tracks.dropFirst()).allSatisfy { $0.range.upperBound == $1.range.lowerBound }
    }
}

/// Converts `ParsedTrack`s into `PlannedTrack`s.
public struct ExportPlanner: Sendable {

    public init() {}

    /// - Parameters:
    ///   - tracks: Parser output (possibly user-edited), in tracklist order.
    ///   - source: Inspected source audio.
    ///   - leadIn: What to do with audio before the first timestamp.
    ///   - album: Used to name the single track when `tracks` is empty.
    ///   - template: Filename layout.
    ///
    /// Ranges tile `[firstStart, totalFrames)` where `firstStart` is `0`
    /// unless `leadIn == .trim` and the first timestamp is after 0:00.
    /// Tracks starting at or past the end are dropped with a warning; tracks
    /// are ordered by time and equal start frames keep only the first.
    public func plan(
        tracks: [ParsedTrack],
        source: AudioSourceInfo,
        leadIn: ParseOptions.LeadInStrategy,
        albumTitle: String,
        template: FilenameTemplate = .numberArtistTitle
    ) -> ExportPlan {
        let total = source.totalFrames
        var warnings: [ParseWarning] = []

        // Convert to frames, drop out-of-range, order by time, drop equal starts.
        var candidates: [(track: ParsedTrack, frame: Int64)] = []
        for track in tracks {
            let frame = max(0, Int64((track.start.seconds * source.sampleRate).rounded()))
            if frame >= total {
                warnings.append(.startBeyondSourceDuration(track.start))
            } else {
                candidates.append((track, frame))
            }
        }
        candidates = candidates.enumerated()
            .sorted { ($0.element.frame, $0.offset) < ($1.element.frame, $1.offset) }
            .map(\.element)
        var kept: [(track: ParsedTrack, frame: Int64)] = []
        for c in candidates where kept.last?.frame != c.frame { kept.append(c) }

        // Empty (or fully dropped) tracklist → one track named after the album.
        if kept.isEmpty {
            let name = albumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let single = ParsedTrack(
                index: 1, start: Timestamp(seconds: 0), artists: [],
                titles: [name.isEmpty ? "Track 1" : name], rawText: "")
            let file = FilenameSanitizer.filename(
                number: 1, artist: "", title: single.title, template: template)
            let planned = PlannedTrack(track: single, range: 0..<max(total, 1), trackNumber: 1, filename: file)
            return ExportPlan(tracks: [planned], warnings: warnings)
        }

        // Ranges: [start, nextStart), last runs to the end.
        var ranges: [Range<Int64>] = []
        for (i, c) in kept.enumerated() {
            let lower = (i == 0 && leadIn == .includeInFirstTrack) ? 0 : c.frame
            let upper = i + 1 < kept.count ? kept[i + 1].frame : total
            ranges.append(lower..<upper)
        }

        let names = FilenameSanitizer.uniqued(kept.enumerated().map { i, c in
            FilenameSanitizer.filename(
                number: i + 1, artist: c.track.artist,
                title: c.track.title.isEmpty ? "Track \(i + 1)" : c.track.title, template: template)
        })

        var planned: [PlannedTrack] = []
        for (i, c) in kept.enumerated() {
            var track = c.track
            track.index = i + 1
            // The parser only sees gaps between timestamps; the last track's
            // length depends on the real duration, so re-check it here.
            let seconds = Double(ranges[i].upperBound - ranges[i].lowerBound) / source.sampleRate
            if seconds < 5, !track.warnings.contains(.trackShorterThanFiveSeconds) {
                track.warnings.append(.trackShorterThanFiveSeconds)
            }
            planned.append(PlannedTrack(track: track, range: ranges[i], trackNumber: i + 1, filename: names[i]))
        }
        return ExportPlan(tracks: planned, warnings: warnings)
    }
}
