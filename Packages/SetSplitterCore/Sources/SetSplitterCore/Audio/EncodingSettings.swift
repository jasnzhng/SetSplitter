//
//  EncodingSettings.swift
//  SetSplitterCore
//
//  implementation.md §7. Output-settings dictionaries for the reader (LPCM)
//  and each track writer. Sample rate and channel count always come from the
//  source; nothing is ever resampled.
//

import AVFoundation

enum EncodingSettings {

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
                AVEncoderBitRateKey: kbps * 1000,
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
