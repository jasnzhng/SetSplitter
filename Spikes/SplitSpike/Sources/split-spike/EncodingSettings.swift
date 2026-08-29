import AVFoundation

// MARK: - Encoding settings

enum SpikeCodec: String {
    case aac
    case alac
}

enum EncodingSettings {
    /// Output settings dictionary for an `AVAssetWriterInput` of media type `.audio`.
    /// Sample rate and channel count are always inherited from the source (implementation.md §2.2, §7).
    static func settings(codec: SpikeCodec, sampleRate: Double, channels: Int, aacBitrateKbps: Int) -> [String: Any] {
        var layout = AudioChannelLayout()
        layout.mChannelLayoutTag = channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo
        let layoutData = Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)

        switch codec {
        case .aac:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: aacBitrateKbps * 1000,
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

    /// LPCM settings for the reader. Interleaved 32-bit float makes frame-accurate splitting simple (§7.3).
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
