//
//  TracklistParser.swift
//  SetSplitterCore
//
//  Public entry point. A pure, deterministic pipeline:
//
//    normalise → TimestampScanner → per segment:
//        SegmentCleaner → EntrySplitter → SegmentCleaner → CreditParser
//        → TrackAssembler
//    → validation warnings
//
//  Timestamps are the only thing that creates a track; nothing here depends on
//  newlines. Parsing never throws — every problem is a `ParseWarning`.
//

import Foundation

/// Parses arbitrary pasted tracklist text into `ParsedTrack`s.
///
/// Stateless and deterministic: the same `(text, options)` always yields the
/// same `ParseResult`. Safe to call on every keystroke.
public struct TracklistParser: Sendable {

    public init() {}

    /// Parses `text` under `options`.
    public func parse(text: String, options: ParseOptions = .default) -> ParseResult {
        let normalized = Self.normalize(text)

        let scanner = TimestampScanner()
        let segments = scanner.scan(normalized)
        guard !segments.isEmpty else {
            return ParseResult(tracks: [], warnings: [.noTimestampsFound, .noTracksParsed])
        }

        let cleaner = SegmentCleaner()
        let entrySplitter = EntrySplitter()
        let creditParser = CreditParser()
        let assembler = TrackAssembler()

        var tracks: [ParsedTrack] = []
        for (offset, segment) in segments.enumerated() {
            let cleanedSegment = cleaner.clean(segment.text, options: options)
            let entries = entrySplitter.split(cleanedSegment)
            let credits = entries.map { entry in
                creditParser.parse(cleaner.clean(entry, options: options), options: options)
            }
            tracks.append(
                assembler.assemble(
                    index: offset + 1,
                    start: segment.start,
                    rawText: segment.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    credits: credits,
                    options: options
                )
            )
        }

        var documentWarnings: [ParseWarning] = []
        tracks = dropDuplicateStarts(tracks, into: &documentWarnings)
        flagNonMonotonic(&tracks)
        flagShortTracks(&tracks)
        if let first = tracks.first, first.start.seconds > 0 {
            documentWarnings.append(.firstTimestampNotZero(first.start))
        }

        for i in tracks.indices { tracks[i].index = i + 1 }

        if tracks.isEmpty { documentWarnings.append(.noTracksParsed) }

        return ParseResult(tracks: tracks, warnings: documentWarnings)
    }

    // MARK: - Normalisation

    /// CRLF/CR/U+2028/U+2029 → LF, NBSP and other Unicode spaces → ASCII space,
    /// invisible zero-width characters removed (but not the ZWJ, which glues emoji
    /// sequences together). Done once up front so every downstream stage —
    /// including `TimestampScanner`, which runs before `SegmentCleaner` — sees
    /// clean text. (This could live in `SegmentCleaner`, but the scanner
    /// runs first, so it is hoisted here.)
    static func normalize(_ text: String) -> String {
        // CRLF first so it becomes one LF, then any lone CR (classic Mac endings).
        let lines = text.replacing("\r\n", with: "\n")
        var out = String()
        out.reserveCapacity(lines.count)
        for scalar in lines.unicodeScalars {
            switch scalar.value {
            case 0x0D, 0x2028, 0x2029:       // lone CR, line/paragraph separator → LF
                out.unicodeScalars.append("\n")
            case 0x200B, 0x200C, 0xFEFF:     // ZWSP, ZWNJ, BOM (ZWJ deliberately kept)
                continue
            case 0x00A0, 0x2007, 0x202F, 0x2009, 0x2002...0x2006, 0x2008, 0x205F, 0x3000:
                out.unicodeScalars.append(" ")
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    // MARK: - Validation

    /// Same timestamp twice → keep the first, warn once per repeated value.
    private func dropDuplicateStarts(_ tracks: [ParsedTrack], into warnings: inout [ParseWarning]) -> [ParsedTrack] {
        var seen = Set<Double>()
        var reported = Set<Double>()
        var kept: [ParsedTrack] = []
        for track in tracks {
            if seen.contains(track.start.seconds) {
                if reported.insert(track.start.seconds).inserted {
                    warnings.append(.duplicateTimestamp(track.start))
                }
                continue
            }
            seen.insert(track.start.seconds)
            kept.append(track)
        }
        return kept
    }

    /// Validation: timestamps not strictly increasing → warn on the offender.
    private func flagNonMonotonic(_ tracks: inout [ParsedTrack]) {
        guard tracks.count > 1 else { return }
        for i in 1..<tracks.count where tracks[i].start <= tracks[i - 1].start {
            if !tracks[i].warnings.contains(.timestampNotIncreasing) {
                tracks[i].warnings.append(.timestampNotIncreasing)
            }
        }
    }

    /// Validation: a gap to the next track under `TrackTiming.shortTrackThreshold` → warn. The last
    /// track's length needs the source duration and is checked by the planner.
    private func flagShortTracks(_ tracks: inout [ParsedTrack]) {
        guard tracks.count > 1 else { return }
        for i in 0..<(tracks.count - 1) {
            let gap = tracks[i + 1].start.seconds - tracks[i].start.seconds
            if gap > 0, gap < TrackTiming.shortTrackThreshold, !tracks[i].warnings.contains(.trackShorterThanFiveSeconds) {
                tracks[i].warnings.append(.trackShorterThanFiveSeconds)
            }
        }
    }
}
