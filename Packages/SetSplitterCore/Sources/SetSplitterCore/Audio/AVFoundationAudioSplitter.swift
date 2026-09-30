//
//  AudioSplitter.swift
//  SetSplitterCore
//
//  implementation.md §7. Single streaming decode pass: AVAssetReader → LPCM
//  sample buffers → one AVAssetWriter per track, cutting buffers at the exact
//  frame index of each boundary. Never holds more than a few buffers in RAM.
//

import AVFoundation

public struct AVFoundationAudioSplitter: AudioSplitting {

    public init() {}

    public func split(
        source: URL,
        sourceInfo: AudioSourceInfo,
        plan: [PlannedTrack],
        directory: URL,
        settings: ExportSettings,
        metadata: AlbumMetadata,
        progress: @escaping @Sendable (ExportProgress) -> Void
    ) async throws -> [URL] {
        guard !plan.isEmpty else { throw ExportError.emptyPlan }

        let asset = AVURLAsset(url: source, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = tracks.first else { throw InspectionError.noAudioTrack }

        let sampleRate = sourceInfo.sampleRate
        let channels = sourceInfo.channels

        let reader: AVAssetReader
        do { reader = try AVAssetReader(asset: asset) } catch {
            throw ExportError.readerFailed(error.localizedDescription)
        }
        let output = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: EncodingSettings.readerLPCM(sampleRate: sampleRate, channels: channels))
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else {
            throw ExportError.readerFailed(reader.error?.localizedDescription ?? "Couldn't start reading.")
        }

        let encoder = EncodingSettings.writer(codec: settings.codec, sampleRate: sampleRate, channels: channels)
        let firstFrame = plan[0].range.lowerBound
        let progressTotal = max(1, sourceInfo.totalFrames - firstFrame)
        let throttle = ProgressThrottle(interval: .milliseconds(100))

        var outputs: [URL] = []
        var writer: TrackWriter?
        var trackIndex = 0            // index into `plan` of the track being written
        var written: Int64 = 0        // frames appended to the current writer
        var cursor: Int64 = 0         // source frame at the start of the buffer being routed

        func report(force: Bool = false, phase: ExportProgress.Phase = .writing) {
            let i = min(trackIndex, plan.count - 1)
            let snapshot = ExportProgress(
                phase: phase, framesProcessed: min(progressTotal, max(0, cursor - firstFrame)),
                totalFrames: progressTotal, currentTrack: i + 1, trackCount: plan.count,
                currentTitle: plan[i].displayTitle)
            if force || throttle.shouldEmit() { progress(snapshot) }
        }

        do {
            report(force: true)
            readLoop: while trackIndex < plan.count {
                try Task.checkCancellation()
                guard var buffer = output.copyNextSampleBuffer() else { break }
                var remaining = CMSampleBufferGetNumSamples(buffer)

                // Route this buffer's frames [cursor, cursor + remaining) into tracks.
                while remaining > 0 {
                    guard trackIndex < plan.count else { break readLoop }
                    let range = plan[trackIndex].range
                    let isLast = trackIndex == plan.count - 1
                    // The last track always runs to EOF: the decoder can yield a few frames
                    // more than round(duration × rate), and they belong to the last track.
                    let upper = isLast ? Int64.max : range.upperBound

                    // Before this track's start (trimmed lead-in): discard.
                    if cursor < range.lowerBound {
                        let skip = Int(min(Int64(remaining), range.lowerBound - cursor))
                        if skip == remaining { cursor += Int64(skip); remaining = 0; continue }
                        buffer = try SampleBufferSplitting.split(buffer, headFrames: skip).tail
                        cursor += Int64(skip); remaining -= skip
                        continue
                    }

                    let room = upper - cursor
                    let take = Int(min(Int64(remaining), room))

                    let current: TrackWriter
                    if let w = writer { current = w } else {
                        current = try makeWriter(for: plan[trackIndex], in: directory, encoder: encoder,
                                                 metadata: metadata, trackCount: plan.count)
                        writer = current
                        written = 0
                    }

                    let head: CMSampleBuffer
                    let tail: CMSampleBuffer?
                    if take < remaining {
                        let parts = try SampleBufferSplitting.split(buffer, headFrames: take)
                        head = parts.head; tail = parts.tail
                    } else {
                        head = buffer; tail = nil
                    }

                    let retimed = try SampleBufferSplitting.retimed(head, toStartFrame: Int(written), sampleRate: sampleRate)
                    try await current.append(retimed)
                    written += Int64(take)
                    cursor += Int64(take)
                    remaining -= take
                    report()

                    if cursor >= upper {           // this track is complete
                        try await current.finish()
                        outputs.append(current.outputURL)
                        writer = nil
                        trackIndex += 1
                    }
                    if let tail { buffer = tail }
                }
            }

            if reader.status == .failed {
                throw ExportError.readerFailed(reader.error?.localizedDescription ?? "Unknown decoder error.")
            }

            // EOF: close the open (last) track; anything not yet started means the file was shorter than the plan.
            if let w = writer {
                try await w.finish()
                outputs.append(w.outputURL)
                writer = nil
                trackIndex += 1
            }
            if outputs.count < plan.count { throw ExportError.sourceEndedEarly(track: outputs.count + 1) }
            report(force: true)
            return outputs
        } catch {
            writer?.cancel()
            reader.cancelReading()
            for url in outputs { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }

    private func makeWriter(
        for planned: PlannedTrack, in directory: URL, encoder: [String: Any],
        metadata: AlbumMetadata, trackCount: Int
    ) throws -> TrackWriter {
        let items = MetadataBuilder.items(for: planned, album: metadata, totalTracks: trackCount)
        return try TrackWriter(
            outputURL: directory.appendingPathComponent(planned.filename),
            encoderSettings: encoder, metadata: items)
    }
}
