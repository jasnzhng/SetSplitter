import AVFoundation
import Foundation
import Testing
@testable import SetSplitterCore

enum AudioTestSupport {

    /// Fixtures/audio/<name>, located via #filePath (SwiftPM tests have no reliable CWD).
    static func fixture(_ name: String, file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/audio/\(name)")
    }

    /// Decodes a file to interleaved float samples via AVAssetReader (which honours iTunSMPB trimming).
    static func decode(_ url: URL) async throws -> (samples: [Float], channels: Int) {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let fd = try #require(try await track.load(.formatDescriptions).first)
        let asbd = try #require(CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee)
        let channels = Int(asbd.mChannelsPerFrame)
        let reader = try AVAssetReader(asset: asset)
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: EncodingSettings.readerLPCM(
            sampleRate: asbd.mSampleRate, channels: channels))
        reader.add(out)
        reader.startReading()
        var samples: [Float] = []
        while let sb = out.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sb) else { continue }
            let len = CMBlockBufferGetDataLength(block)
            var chunk = [Float](repeating: 0, count: len / MemoryLayout<Float>.size)
            chunk.withUnsafeMutableBytes { _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: len, destination: $0.baseAddress!) }
            samples.append(contentsOf: chunk)
        }
        return (samples, channels)
    }

    /// Decoded frame count via AVAssetReader (which honours iTunSMPB), streaming: nothing is kept in memory.
    static func frameCount(_ url: URL) async throws -> Int64 {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let fd = try #require(try await track.load(.formatDescriptions).first)
        let asbd = try #require(CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee)
        let reader = try AVAssetReader(asset: asset)
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: EncodingSettings.readerLPCM(
            sampleRate: asbd.mSampleRate, channels: Int(asbd.mChannelsPerFrame)))
        reader.add(out)
        reader.startReading()
        var frames: Int64 = 0
        while let sb = out.copyNextSampleBuffer() { frames += Int64(CMSampleBufferGetNumSamples(sb)) }
        return frames
    }

    /// Raw `ilst` payloads keyed by atom fourcc (e.g. "trkn", "aART"). AVAsset.load(.metadata) is *not*
    /// a real verification (Phase 0 finding), so this walks the file bytes.
    static func ilst(_ url: URL) throws -> [String: Data] {
        let d = try Data(contentsOf: url)
        var result: [String: Data] = [:]
        func be32(_ i: Int) -> Int { Int(d[i]) << 24 | Int(d[i+1]) << 16 | Int(d[i+2]) << 8 | Int(d[i+3]) }
        func cc(_ i: Int) -> String { String(decoding: d[i..<i+4].map { $0 }, as: UTF8.self) }
        func cc1(_ i: Int) -> String { String(String.UnicodeScalarView(d[i..<i+4].map { Unicode.Scalar($0) })) }
        func walk(_ start: Int, _ end: Int) {
            var i = start
            while i + 8 <= end {
                var size = be32(i); let type = cc1(i + 4)
                if size == 1, i + 16 <= end { size = be32(i + 12) }   // 64-bit largesize (AVAssetWriter's mdat)
                guard size >= 8, i + size <= end else { return }
                switch type {
                case "moov", "udta": walk(i + 8, i + size)
                case "meta": walk(i + 12, i + size)
                case "ilst":
                    var j = i + 8
                    while j + 8 <= i + size {
                        let asz = be32(j); let name = cc1(j + 4)
                        guard asz >= 8 else { break }
                        if j + 16 + 8 <= j + asz, cc1(j + 12) == "data" {
                            result[name] = d[(j + 24)..<(j + asz)]
                        }
                        j += asz
                    }
                default: break
                }
                i += size
            }
        }
        walk(0, d.count)
        return result
    }

    static func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SetSplitterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
