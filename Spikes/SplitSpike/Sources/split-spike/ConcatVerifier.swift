import AVFoundation

// MARK: - Gapless verification

struct DecodeResult {
    var samples: [Float]     // interleaved
    var frames: Int
    var sampleRate: Double
    var channels: Int
}

struct SeamReport {
    let boundaryFrame: Int
    let maxAbsDiffVsSource: Float   // window compare against the original decode
    let rmsVsSource: Float
    let maxAdjacentJumpAtSeam: Float // click detector: largest |x[n]-x[n-1]| within ±16 frames of the cut
    let typicalAdjacentJump: Float   // median |x[n]-x[n-1]| across the whole file, for scale
}

struct ConcatReport {
    let sourceFrames: Int
    let outputFramesTotal: Int
    let perFileFrames: [Int]
    let frameDelta: Int              // outputFramesTotal - sourceFrames ; 0 == gapless proven structurally
    let bitExact: Bool              // whole-file max abs diff < 1e-6 (meaningful for ALAC)
    let wholeFileMaxAbsDiff: Float
    let seams: [SeamReport]
    let expectedFramesFromDuration: Int  // duration.seconds * sampleRate, rounded
    let readerDurationDelta: Int         // sourceFrames - expectedFramesFromDuration
}

enum ConcatVerifier {
    static func decode(_ url: URL) throws -> DecodeResult {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let track = assetAudioTrack(asset) else {
            throw NSError(domain: "spike", code: 1, userInfo: [NSLocalizedDescriptionKey: "no audio track in \(url.lastPathComponent)"])
        }
        guard let fd = firstAudioFormatDescription(track),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee else {
            throw NSError(domain: "spike", code: 3, userInfo: [NSLocalizedDescriptionKey: "no format description in \(url.lastPathComponent)"])
        }
        let sampleRate = asbd.mSampleRate
        let channels = Int(asbd.mChannelsPerFrame)

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: EncodingSettings.readerLPCM(sampleRate: sampleRate, channels: channels))
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []
        samples.reserveCapacity(1 << 22)
        while let sb = output.copyNextSampleBuffer() {
            guard let bb = CMSampleBufferGetDataBuffer(sb) else { continue }
            var len = 0
            var ptr: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(bb, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &len, dataPointerOut: &ptr)
            if let ptr {
                ptr.withMemoryRebound(to: Float.self, capacity: len / 4) { fp in
                    samples.append(contentsOf: UnsafeBufferPointer(start: fp, count: len / 4))
                }
            }
        }
        if reader.status == .failed { throw reader.error ?? NSError(domain: "spike", code: 2) }

        let frames = channels > 0 ? samples.count / channels : 0
        return DecodeResult(samples: samples, frames: frames, sampleRate: sampleRate, channels: channels)
    }

    static func verify(source: URL, outputs: [URL], boundaryFramesInSource: [Int]) throws -> ConcatReport {
        let src = try decode(source)

        var concat: [Float] = []
        var perFile: [Int] = []
        for url in outputs {
            let d = try decode(url)
            perFile.append(d.frames)
            concat.append(contentsOf: d.samples)
        }
        let outFrames = src.channels > 0 ? concat.count / src.channels : 0

        // Whole-file diff (only meaningful when lengths match; compare the overlap otherwise).
        let ch = max(src.channels, 1)
        let cmpFrames = min(src.frames, outFrames)
        var maxAbs: Float = 0
        var idx = 0
        let limit = cmpFrames * ch
        while idx < limit {
            let diff = abs(src.samples[idx] - concat[idx])
            if diff > maxAbs { maxAbs = diff }
            idx += 1
        }

        // Typical adjacent jump across source, for the click detector scale.
        var jumps: [Float] = []
        jumps.reserveCapacity(min(limit, 200_000))
        var j = ch
        var step = 0
        while j < limit && jumps.count < 200_000 {
            if step % 7 == 0 { jumps.append(abs(concat[j] - concat[j - ch])) }
            j += ch
            step += 1
        }
        jumps.sort()
        let typical = jumps.isEmpty ? 0 : jumps[jumps.count / 2]

        var seams: [SeamReport] = []
        let win = 1024
        for b in boundaryFramesInSource where b > win && b < cmpFrames - win {
            var mad: Float = 0
            var sse: Float = 0
            var n: Float = 0
            for f in (b - win)..<(b + win) {
                for c in 0..<ch {
                    let s = src.samples[f * ch + c]
                    let o = concat[f * ch + c]
                    let dd = abs(s - o)
                    if dd > mad { mad = dd }
                    sse += dd * dd
                    n += 1
                }
            }
            var maxJump: Float = 0
            for f in (b - 16)..<(b + 16) {
                for c in 0..<ch {
                    let jmp = abs(concat[f * ch + c] - concat[(f - 1) * ch + c])
                    if jmp > maxJump { maxJump = jmp }
                }
            }
            seams.append(SeamReport(
                boundaryFrame: b,
                maxAbsDiffVsSource: mad,
                rmsVsSource: (sse / n).squareRoot(),
                maxAdjacentJumpAtSeam: maxJump,
                typicalAdjacentJump: typical))
        }

        // Reader frame count vs duration-derived count.
        let asset = AVURLAsset(url: source, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let expected = Int((assetDurationSeconds(asset) * src.sampleRate).rounded())

        return ConcatReport(
            sourceFrames: src.frames,
            outputFramesTotal: outFrames,
            perFileFrames: perFile,
            frameDelta: outFrames - src.frames,
            bitExact: maxAbs < 1e-6 && outFrames == src.frames,
            wholeFileMaxAbsDiff: maxAbs,
            seams: seams,
            expectedFramesFromDuration: expected,
            readerDurationDelta: src.frames - expected)
    }
}

func assetAudioTrack(_ asset: AVAsset) -> AVAssetTrack? {
    blockingLoad { try await asset.loadTracks(withMediaType: .audio).first }
}

/// Spike-only bridge: run one `AVAsset` async loader synchronously. The real Core is fully async.
func blockingLoad<T>(_ work: @escaping () async throws -> T?) -> T? {
    let sem = DispatchSemaphore(value: 0)
    var result: T?
    Task {
        result = try? await work()
        sem.signal()
    }
    sem.wait()
    return result
}

func assetDurationSeconds(_ asset: AVAsset) -> Double {
    guard let d = blockingLoad({ try await asset.load(.duration) }) else { return 0 }
    return CMTimeGetSeconds(d)
}

func firstAudioFormatDescription(_ track: AVAssetTrack) -> CMAudioFormatDescription? {
    let descs = blockingLoad { try await track.load(.formatDescriptions) } ?? []
    return descs.first.map { $0 as CMAudioFormatDescription }
}
