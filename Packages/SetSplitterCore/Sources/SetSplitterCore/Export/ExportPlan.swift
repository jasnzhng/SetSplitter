//
//  ExportPlan.swift
//  SetSplitterCore
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
