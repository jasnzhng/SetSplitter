import AVFoundation

// MARK: - One AVAssetWriter per output track

enum TrackWriterError: Error {
    case cannotAddInput
    case startWritingFailed(Error?)
    case finishFailed(Error?)
    case appendFailed
}

/// Wraps a single `AVAssetWriter` + audio input for one output file.
/// Session starts at `.zero`; callers must retime buffers so the first frame lands at time zero.
final class TrackWriter {
    let outputURL: URL
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private var started = false

    init(outputURL: URL, encoderSettings: [String: Any], metadata: [AVMetadataItem]) throws {
        self.outputURL = outputURL
        try? FileManager.default.removeItem(at: outputURL)
        writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        writer.metadata = metadata  // MUST be set before startWriting()

        input = AVAssetWriterInput(mediaType: .audio, outputSettings: encoderSettings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw TrackWriterError.cannotAddInput }
        writer.add(input)
    }

    func startIfNeeded(atSourceTime time: CMTime = .zero) throws {
        guard !started else { return }
        guard writer.startWriting() else {
            throw TrackWriterError.startWritingFailed(writer.error)
        }
        writer.startSession(atSourceTime: time)
        started = true
    }

    /// Blocking append (spike only — real Core uses the requestMediaDataWhenReady stream).
    func append(_ buffer: CMSampleBuffer) throws {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.002)
        }
        guard input.append(buffer) else {
            throw TrackWriterError.appendFailed
        }
    }

    func finish() throws {
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()
        guard writer.status == .completed else {
            throw TrackWriterError.finishFailed(writer.error)
        }
    }

    func cancel() {
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: outputURL)
    }
}
