//
//  ParseWarning.swift
//  SetSplitterCore
//
//  implementation.md §5 (validation), §5.4a, §6. Parsing never hard-fails;
//  every problem is a warning. Document-level warnings live on
//  `ParseResult.warnings`; track-level warnings live on `ParsedTrack.warnings`.
//  Only `.noTracksParsed` blocks the wizard's Next button (UI concern).
//

import Foundation

/// A non-fatal problem found while parsing a tracklist.
///
/// Surfaced in the UI as a small yellow list beneath the preview. `message`
/// is the user-facing text; `isBlocking` marks the one case that should stop
/// the user proceeding.
public enum ParseWarning: Hashable, Sendable {

    /// No `mm:ss` / `h:mm:ss` timestamps anywhere in the input.
    case noTimestampsFound

    /// Timestamps were found but no usable track came out of the pipeline.
    case noTracksParsed

    /// The first track does not start at 0:00. Whether this matters depends on
    /// `ParseOptions.leadInStrategy`; the warning is informational.
    case firstTimestampNotZero(Timestamp)

    /// This track's start is not strictly after the previous track's start.
    /// Track-level; attached to the later (offending) track.
    case timestampNotIncreasing

    /// Two tracks share this exact start time. Document-level.
    case duplicateTimestamp(Timestamp)

    /// The gap to the next track is under 5 seconds. Track-level.
    case trackShorterThanFiveSeconds

    /// No artist/title separator was found in the entry. Track-level.
    case missingArtist

    /// The track ended up with no title text. Track-level.
    case emptyTitle

    /// The track's start is at or past the source duration and it was dropped.
    /// Produced by the export planner (Phase 3), defined here for one home.
    case startBeyondSourceDuration(Timestamp)
}

// MARK: - Presentation

public extension ParseWarning {

    /// `true` only for `.noTracksParsed` — the sole warning that should block
    /// the user from advancing.
    var isBlocking: Bool {
        if case .noTracksParsed = self { return true }
        return false
    }

    /// User-facing description for the warnings list.
    var message: String {
        switch self {
        case .noTimestampsFound:
            return "No timestamps found. A tracklist needs times like 0:00 or 1:02:03 to split on."
        case .noTracksParsed:
            return "Couldn't parse any tracks from this tracklist."
        case .firstTimestampNotZero(let ts):
            return "First track starts at \(ts.displayString), not 0:00. Audio before it will be included in track 1 unless you choose to trim it."
        case .timestampNotIncreasing:
            return "This track's timestamp is not later than the previous one."
        case .duplicateTimestamp(let ts):
            return "Two tracks start at \(ts.displayString). The first one is kept."
        case .trackShorterThanFiveSeconds:
            return "This track is under 5 seconds long."
        case .missingArtist:
            return "No artist could be separated from the title."
        case .emptyTitle:
            return "This track has no title."
        case .startBeyondSourceDuration(let ts):
            return "A track starts at \(ts.displayString), past the end of the audio, and was dropped."
        }
    }
}
