//
//  AudioSourceInfo.swift
//  SetSplitterCore
//
//  What the inspector learns about the source file. Everything the planner and
//  the Import screen's confirmation line need, with no AVFoundation types.
//

import Foundation

/// Facts about the imported audio file.
public struct AudioSourceInfo: Hashable, Sendable {

    /// Duration in seconds, measured with precise timing (VBR-safe).
    public var duration: Double

    public var sampleRate: Double

    public var channels: Int

    /// Short codec label for display, e.g. `"MP3"`.
    public var codecName: String

    /// Estimated source bitrate in kilobits per second, when known.
    public var bitrateKbps: Int?

    public init(
        duration: Double,
        sampleRate: Double,
        channels: Int,
        codecName: String = "Audio",
        bitrateKbps: Int? = nil
    ) {
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
        self.codecName = codecName
        self.bitrateKbps = bitrateKbps
    }

    /// Total decoded frames, `round(duration × sampleRate)`. The planner clamps
    /// every cut point to `[0, totalFrames]` (Phase 0 §13 Q3: this matches what
    /// `AVAssetReader` actually decodes, even for MP3s with no Xing header).
    public var totalFrames: Int64 {
        Int64((duration * sampleRate).rounded())
    }

    /// One-line summary for the Import screen, e.g. `"MP3 · 44.1 kHz · Stereo"`.
    public var summary: String {
        let rate = sampleRate.truncatingRemainder(dividingBy: 1000) == 0
            ? String(format: "%.0f kHz", sampleRate / 1000)
            : String(format: "%.1f kHz", sampleRate / 1000)
        let layout: String
        switch channels {
        case 1: layout = "Mono"
        case 2: layout = "Stereo"
        default: layout = "\(channels) channels"
        }
        return [codecName, rate, layout].joined(separator: " · ")
    }
}
