//
//  ExportProgress.swift
//  SetSplitterCore
//
//  implementation.md §7.8. Delivered by the splitter at most ~10×/s.
//

import Foundation

/// A snapshot of an in-flight export.
public struct ExportProgress: Hashable, Sendable {

    public enum Phase: String, Hashable, Sendable {
        /// Decoding, cutting and encoding.
        case writing
        /// Moving the finished folder into place.
        case finalizing
        case done
    }

    public var phase: Phase

    /// Source frames consumed so far, counted from the first exported frame.
    public var framesProcessed: Int64

    public var totalFrames: Int64

    /// 1-based index of the track being written.
    public var currentTrack: Int

    public var trackCount: Int

    /// Display title of the track being written.
    public var currentTitle: String

    public init(
        phase: Phase = .writing,
        framesProcessed: Int64 = 0,
        totalFrames: Int64 = 0,
        currentTrack: Int = 1,
        trackCount: Int = 1,
        currentTitle: String = ""
    ) {
        self.phase = phase
        self.framesProcessed = framesProcessed
        self.totalFrames = totalFrames
        self.currentTrack = currentTrack
        self.trackCount = trackCount
        self.currentTitle = currentTitle
    }

    /// 0…1, clamped. `1` once `phase == .done`.
    public var fraction: Double {
        if phase == .done { return 1 }
        guard totalFrames > 0 else { return 0 }
        return min(1, max(0, Double(framesProcessed) / Double(totalFrames)))
    }
}
