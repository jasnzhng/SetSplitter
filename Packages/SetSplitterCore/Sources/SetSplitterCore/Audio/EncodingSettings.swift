//
//  EncodingSettings.swift
//  SetSplitterCore
//
//  implementation.md §7. Output-settings dictionaries for the reader (LPCM)
//  and each track writer. Channel count always comes from the source. Sample
//  rate does too, unless AAC can't encode it (hi-res WAVs): then the single
//  reader pass resamples once, before any cut, so seams stay sample-exact.
//

import AudioToolbox
import AVFoundation

enum EncodingSettings {

    /// Rates the AAC encoder accepts (`kAudioFormatProperty_AvailableEncodeSampleRates`).
    /// Asking `AVAssetWriterInput` for anything else raises an Objective-C exception,
    /// which Swift can't catch, so unsupported rates must be mapped before a writer exists.
    private static let aacSampleRates: [Double] = [
        8_000, 11_025, 12_000, 16_000, 22_050, 24_000, 32_000, 44_100, 48_000,
    ]

    /// The rate to decode and encode at for a source of `rate` Hz: the source's own rate when AAC
    /// supports it, otherwise the nearest supported rate below it. Rates above 48 kHz are halved
    /// first so 96 kHz → 48 kHz and 88.2 kHz → 44.1 kHz keep a clean integer ratio.
    static func encodableSampleRate(for rate: Double) -> Double {
        if aacSampleRates.contains(rate) { return rate }
        var candidate = rate
        while candidate > 48_000 { candidate /= 2 }
        if !aacSampleRates.contains(candidate) { candidate = rate }
        return aacSampleRates.last { $0 <= candidate } ?? aacSampleRates[0]
    }

    static func writer(codec: ExportSettings.Codec, sampleRate: Double, channels: Int) -> [String: Any] {
        var layout = AudioChannelLayout()
        layout.mChannelLayoutTag = channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo
        let layoutData = Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)

        switch codec {
        case .aac(let kbps):
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: aacBitRate(requestedKbps: kbps, sampleRate: sampleRate, channels: channels),
                AVChannelLayoutKey: layoutData,
            ]
        case .alac:
            return [
                AVFormatIDKey: kAudioFormatAppleLossless,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitDepthHintKey: 16,
                AVChannelLayoutKey: layoutData,
            ]
        }
    }

    /// The bitrate to ask the AAC encoder for: `requestedKbps`, lowered to the most the encoder accepts
    /// for this rate and channel count. Apple's encoder is stricter than the AAC spec (256 kbps mono
    /// at 22.05 kHz fails with "Cannot Encode Media"; its ceiling there is 64 kbps), so the limit is
    /// read from an `AudioConverter` rather than computed. If the query fails the request is used as-is.
    static func aacBitRate(requestedKbps: Int, sampleRate: Double, channels: Int) -> Int {
        let requested = requestedKbps * 1_000
        guard let ceiling = maxAACBitRate(sampleRate: sampleRate, channels: channels) else { return requested }
        return min(requested, ceiling)
    }

    private static func maxAACBitRate(sampleRate: Double, channels: Int) -> Int? {
        let count = UInt32(channels)
        var source = AudioStreamBasicDescription(
            mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4 * count, mFramesPerPacket: 1, mBytesPerFrame: 4 * count,
            mChannelsPerFrame: count, mBitsPerChannel: 32, mReserved: 0)
        var destination = AudioStreamBasicDescription(
            mSampleRate: sampleRate, mFormatID: kAudioFormatMPEG4AAC, mFormatFlags: 0,
            mBytesPerPacket: 0, mFramesPerPacket: 1024, mBytesPerFrame: 0,
            mChannelsPerFrame: count, mBitsPerChannel: 0, mReserved: 0)
        var converter: AudioConverterRef?
        guard AudioConverterNew(&source, &destination, &converter) == noErr, let converter else { return nil }
        defer { AudioConverterDispose(converter) }

        var size: UInt32 = 0
        guard AudioConverterGetPropertyInfo(converter, kAudioConverterApplicableEncodeBitRates, &size, nil) == noErr,
              size > 0 else { return nil }
        var ranges = [AudioValueRange](repeating: AudioValueRange(), count: Int(size) / MemoryLayout<AudioValueRange>.size)
        guard AudioConverterGetProperty(converter, kAudioConverterApplicableEncodeBitRates, &size, &ranges) == noErr
        else { return nil }
        return ranges.map { Int($0.mMaximum) }.max()
    }

    /// Interleaved 32-bit float makes frame-accurate splitting simple (§7.3).
    static func readerLPCM(sampleRate: Double, channels: Int) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
        ]
    }
}
