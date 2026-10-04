//
//  TrackTiming.swift
//  SetSplitterCore
//
//  Durations are always derived, never stored.
//

import Foundation

public enum TrackTiming {

    /// Tracks shorter than this (seconds) get a "very short" warning.
    public static let shortTrackThreshold: Double = 5

    /// Duration in seconds of each track: `next.start - this.start`, and for
    /// the last track `sourceDuration - this.start`. Never negative.
    public static func durations(of tracks: [ParsedTrack], sourceDuration: Double) -> [Double] {
        tracks.enumerated().map { i, track in
            let end = i + 1 < tracks.count ? tracks[i + 1].start.seconds : sourceDuration
            return max(0, end - track.start.seconds)
        }
    }

    /// `m:ss` under an hour, `h:mm:ss` otherwise.
    public static func format(_ seconds: Double) -> String {
        Timestamp(seconds: seconds).displayString
    }
}
