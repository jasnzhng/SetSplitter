//
//  TrackWriter.swift
//  SetSplitterCore
//
//  Wraps one AVAssetWriter + audio input for one
//  output file. Not Sendable on purpose: it lives inside a single splitter
//  call and never crosses an isolation boundary.
//

import AVFoundation

final class TrackWriter {

    let outputURL: URL
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput

    init(outputURL: URL, encoderSettings: [String: Any], metadata: [AVMetadataItem]) throws {
        self.outputURL = outputURL
        try? FileManager.default.removeItem(at: outputURL)
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        } catch {
            throw TrackWriter.map(error)
        }
        writer.metadata = metadata   // must be attached before startWriting()

        input = AVAssetWriterInput(mediaType: .audio, outputSettings: encoderSettings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw ExportError.writerFailed("The encoder rejected the audio settings.") }
        writer.add(input)

        guard writer.startWriting() else { throw TrackWriter.map(writer.error) }
        writer.startSession(atSourceTime: .zero)
    }

    /// Appends a buffer. When the encoder isn't ready it naps 1 ms and re-checks
    /// (the polling fallback: simpler than bridging `requestMediaDataWhenReady`).
    /// The nap is an `await`, so the thread is released rather than blocked.
    func append(_ buffer: CMSampleBuffer) async throws {
        while !input.isReadyForMoreMediaData {
            try Task.checkCancellation()
            if writer.status == .failed { throw TrackWriter.map(writer.error) }
            try await Task.sleep(for: .milliseconds(1))
        }
        guard input.append(buffer) else { throw TrackWriter.map(writer.error) }
    }

    func finish() async throws {
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw TrackWriter.map(writer.error) }
    }

    /// Abandons the file. The temp folder is deleted wholesale by the caller,
    /// but removing the file here keeps cancel tidy if it isn't.
    func cancel() {
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: outputURL)
    }

    private static func map(_ error: Error?) -> ExportError {
        guard let error else { return .writerFailed("Unknown encoder error.") }
        let ns = error as NSError
        if (ns.domain == AVFoundationErrorDomain && ns.code == AVError.diskFull.rawValue)
            || (ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC))
            || (ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError)
            || (ns.userInfo[NSUnderlyingErrorKey] as? NSError)?.code == Int(ENOSPC) {
            return .diskFull
        }
        return .writerFailed(error.localizedDescription)
    }
}
