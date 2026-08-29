import AVFoundation
import Foundation

// MARK: - Streaming split orchestrator  (implementation.md §7)

struct SpikeConfig {
    var input: URL
    var boundarySeconds: [Double]   // sorted, first is usually 0
    var codec: SpikeCodec
    var aacBitrateKbps: Int
    var outputDir: URL
    var album: SpikeAlbumMetadata
    var trackTitles: [String]       // one per output track; falls back to "Track N"
    var trackArtists: [String]
}

struct SpikeResult {
    var outputURLs: [URL]
    var sourceSampleRate: Double
    var sourceChannels: Int
    var framesDecoded: Int
    var expectedFramesFromDuration: Int
    var perTrackFrames: [Int]
    var boundaryFrames: [Int]
    var usedManualSplitPath: Bool
    var apiSplitPathWorked: Bool
    var peakFootprint: UInt64
    var wallClock: TimeInterval
}

enum SpikeError: Error {
    case noAudioTrack
    case readerInitFailed(Error)
    case readerFailed(Error?)
}

enum Spike {
    static func run(_ cfg: SpikeConfig) throws -> SpikeResult {
        let started = Date()
        var peak: UInt64 = 0
        func samplePeak() { peak = max(peak, MemorySampler.physFootprint()) }

        let asset = AVURLAsset(url: cfg.input, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let track = assetAudioTrack(asset) else { throw SpikeError.noAudioTrack }
        guard let fd = firstAudioFormatDescription(track),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee else {
            throw SpikeError.noAudioTrack
        }
        let sampleRate = asbd.mSampleRate
        let channels = Int(asbd.mChannelsPerFrame)
        let expectedFrames = Int((assetDurationSeconds(asset) * sampleRate).rounded())

        // Boundaries → frame indices. Ranges tile [0, +inf); the last track runs to EOF (§7.2).
        var boundaryFrames = cfg.boundarySeconds
            .map { Int(($0 * sampleRate).rounded()) }
            .filter { $0 > 0 }
            .sorted()
        boundaryFrames = Array(Set(boundaryFrames)).sorted()
        let trackCount = boundaryFrames.count + 1

        try? FileManager.default.createDirectory(at: cfg.outputDir, withIntermediateDirectories: true)

        let reader: AVAssetReader
        do { reader = try AVAssetReader(asset: asset) } catch { throw SpikeError.readerInitFailed(error) }
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: EncodingSettings.readerLPCM(sampleRate: sampleRate, channels: channels))
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        let ext = cfg.codec == .alac ? "m4a" : "m4a"
        func makeWriter(index: Int) throws -> TrackWriter {
            let title = index <= cfg.trackTitles.count ? cfg.trackTitles[index - 1] : "Track \(index)"
            let artist = index <= cfg.trackArtists.count ? cfg.trackArtists[index - 1] : cfg.album.albumArtist
            let name = String(format: "%02d %@ - %@.%@", index,
                              artist.isEmpty ? cfg.album.albumArtist : artist, title, ext)
                .replacingOccurrences(of: "/", with: "-")
            let url = cfg.outputDir.appendingPathComponent(name)
            let meta = MetadataBuilder.items(
                for: SpikeTrack(title: title, artist: artist, trackNumber: index),
                album: cfg.album, totalTracks: trackCount)
            let settings = EncodingSettings.settings(
                codec: cfg.codec, sampleRate: sampleRate, channels: channels, aacBitrateKbps: cfg.aacBitrateKbps)
            return try TrackWriter(outputURL: url, encoderSettings: settings, metadata: meta)
        }

        var outputs: [URL] = []
        var perTrackFrames: [Int] = []
        var currentIndex = 1
        var writer = try makeWriter(index: currentIndex)
        try writer.startIfNeeded()

        var globalFrame = 0            // frames consumed from the source
        var trackLocalFrame = 0        // frames appended to the current writer
        var usedManual = false
        var apiWorked = false
        var nextBoundaryPos = 0        // index into boundaryFrames

        func nextBoundary() -> Int? {
            nextBoundaryPos < boundaryFrames.count ? boundaryFrames[nextBoundaryPos] : nil
        }

        readLoop: while true {
            guard let sb = output.copyNextSampleBuffer() else { break }
            samplePeak()
            var buffer = sb
            var bufferFrames = CMSampleBufferGetNumSamples(buffer)
            if bufferFrames == 0 { continue }

            // This buffer covers source frames [globalFrame, globalFrame + bufferFrames).
            // Emit slices until it no longer straddles a boundary.
            while let b = nextBoundary(), b > globalFrame, b < globalFrame + bufferFrames {
                let headFrames = b - globalFrame
                let outcome = try SampleBufferSplitting.split(buffer, headFrames: headFrames)
                if outcome.usedManualPath { usedManual = true } else { apiWorked = true }

                let head = try SampleBufferSplitting.retimed(outcome.head, toStartFrame: trackLocalFrame, sampleRate: sampleRate)
                try writer.append(head)
                trackLocalFrame += headFrames

                try writer.finish()
                outputs.append(writer.outputURL)
                perTrackFrames.append(trackLocalFrame)

                currentIndex += 1
                nextBoundaryPos += 1
                writer = try makeWriter(index: currentIndex)
                try writer.startIfNeeded()
                trackLocalFrame = 0

                globalFrame += headFrames
                buffer = outcome.tail
                bufferFrames = CMSampleBufferGetNumSamples(buffer)
            }

            let retimed = try SampleBufferSplitting.retimed(buffer, toStartFrame: trackLocalFrame, sampleRate: sampleRate)
            try writer.append(retimed)
            trackLocalFrame += bufferFrames
            globalFrame += bufferFrames
        }

        if reader.status == .failed { throw SpikeError.readerFailed(reader.error) }

        try writer.finish()
        outputs.append(writer.outputURL)
        perTrackFrames.append(trackLocalFrame)
        samplePeak()

        return SpikeResult(
            outputURLs: outputs,
            sourceSampleRate: sampleRate,
            sourceChannels: channels,
            framesDecoded: globalFrame,
            expectedFramesFromDuration: expectedFrames,
            perTrackFrames: perTrackFrames,
            boundaryFrames: boundaryFrames,
            usedManualSplitPath: usedManual,
            apiSplitPathWorked: apiWorked,
            peakFootprint: peak,
            wallClock: Date().timeIntervalSince(started))
    }
}
