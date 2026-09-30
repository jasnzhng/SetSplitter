//
//  AudioSourceInspector.swift
//  SetSplitterCore
//
//  implementation.md §7.1, §10. Reads duration / sample rate / channels from
//  the source with precise timing (VBR MP3s lie about duration otherwise).
//

import AVFoundation

public struct AVFoundationAudioInspector: AudioInspecting {

    public init() {}

    public func inspect(url: URL) async throws -> AudioSourceInfo {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        do {
            guard try await asset.load(.isReadable) else {
                throw InspectionError.unreadable("The file isn't readable audio.")
            }
            // A protected (FairPlay) m4a can look readable but fails at export; say so up front.
            guard try await !asset.load(.hasProtectedContent) else {
                throw InspectionError.unreadable("The file is copy-protected, so it can't be split.")
            }
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { throw InspectionError.noAudioTrack }

            let descriptions = try await track.load(.formatDescriptions)
            guard let fd = descriptions.first,
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee,
                  asbd.mSampleRate > 0, asbd.mChannelsPerFrame > 0
            else { throw InspectionError.noAudioTrack }

            guard asbd.mChannelsPerFrame <= 2 else {
                throw InspectionError.unsupportedChannels(Int(asbd.mChannelsPerFrame))
            }

            let duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration > 0 else { throw InspectionError.emptyAudio }

            let rate = try await track.load(.estimatedDataRate)
            let workingRate = EncodingSettings.encodableSampleRate(for: asbd.mSampleRate)
            return AudioSourceInfo(
                duration: duration,
                sampleRate: workingRate,
                originalSampleRate: workingRate == asbd.mSampleRate ? nil : asbd.mSampleRate,
                channels: Int(asbd.mChannelsPerFrame),
                codecName: Self.codecName(asbd.mFormatID, fileExtension: url.pathExtension),
                bitrateKbps: rate > 0 ? Int((rate / 1000).rounded()) : nil)
        } catch let error as InspectionError {
            throw error
        } catch {
            throw InspectionError.unreadable(error.localizedDescription)
        }
    }

    /// Uncompressed PCM is labelled by its container ("WAV", "AIFF") since that's what people call it.
    private static func codecName(_ id: AudioFormatID, fileExtension: String) -> String {
        switch id {
        case kAudioFormatMPEGLayer3: "MP3"
        case kAudioFormatMPEG4AAC: "AAC"
        case kAudioFormatAppleLossless: "ALAC"
        case kAudioFormatLinearPCM: fileExtension.isEmpty ? "PCM" : fileExtension.uppercased()
        case kAudioFormatFLAC: "FLAC"
        default: "Audio"
        }
    }
}
