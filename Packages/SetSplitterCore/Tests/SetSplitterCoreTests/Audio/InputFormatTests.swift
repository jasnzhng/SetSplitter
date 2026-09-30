import AVFoundation
import Foundation
import Testing
@testable import SetSplitterCore

/// The splitter decodes through `AVAssetReader`, so any readable format should split identically.
/// These run the full export on one input per format and check the parts that could differ: the
/// reported source info, exact frame accounting, and how rate and channels carry through.
@Suite("Input formats", .serialized)
struct InputFormatTests {

    /// Where a case's audio comes from: a committed fixture, or a WAV synthesised for the test.
    enum Input: Sendable {
        case fixture(String)
        case wav(rate: Int, channels: Int, bits: Int)
    }

    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let input: Input
        let seconds: Int
        let codec: String
        /// The rate the export works at (what `AudioSourceInfo.sampleRate` should report).
        let sampleRate: Double
        let channels: Int
        /// The file's own rate when AAC can't encode it and the export resamples.
        var resampledFrom: Double? = nil
        var testDescription: String { name }

        func url(in directory: URL) throws -> URL {
            switch input {
            case .fixture(let file):
                return AudioTestSupport.fixture(file)
            case .wav(let rate, let channels, let bits):
                let url = directory.appendingPathComponent("\(name).wav")
                try AudioTestSupport.writeWAV(to: url, sampleRate: rate, channels: channels,
                                              bitsPerSample: bits, seconds: seconds)
                return url
            }
        }
    }

    static let cases = [
        Case(name: "mp3", input: .fixture("short-set.mp3"), seconds: 30, codec: "MP3", sampleRate: 44_100, channels: 2),
        Case(name: "m4a (AAC)", input: .fixture("short-set.m4a"), seconds: 30, codec: "AAC", sampleRate: 44_100, channels: 2),
        Case(name: "wav 44.1k 16-bit stereo", input: .wav(rate: 44_100, channels: 2, bits: 16), seconds: 25,
             codec: "WAV", sampleRate: 44_100, channels: 2),
        Case(name: "wav 48k 24-bit mono", input: .wav(rate: 48_000, channels: 1, bits: 24), seconds: 25,
             codec: "WAV", sampleRate: 48_000, channels: 1),
        Case(name: "wav 22.05k 8-bit mono", input: .wav(rate: 22_050, channels: 1, bits: 8), seconds: 25,
             codec: "WAV", sampleRate: 22_050, channels: 1),
        Case(name: "wav 96k 24-bit stereo (resampled)", input: .wav(rate: 96_000, channels: 2, bits: 24), seconds: 25,
             codec: "WAV", sampleRate: 48_000, channels: 2, resampledFrom: 96_000),
        Case(name: "wav 88.2k 32-bit float stereo (resampled)", input: .wav(rate: 88_200, channels: 2, bits: 32), seconds: 25,
             codec: "WAV", sampleRate: 44_100, channels: 2, resampledFrom: 88_200),
    ]

    @Test("inspection reports the format", arguments: cases)
    func inspects(_ c: Case) async throws {
        let dir = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let info = try await AVFoundationAudioInspector().inspect(url: c.url(in: dir))
        #expect(info.codecName == c.codec)
        #expect(info.sampleRate == c.sampleRate)
        #expect(info.originalSampleRate == c.resampledFrom)
        #expect(info.channels == c.channels)
        #expect(abs(info.duration - Double(c.seconds)) < 0.05, "duration \(info.duration)")
    }

    @Test("splits at the exact cut frames and keeps the channel layout", arguments: cases)
    func splits(_ c: Case) async throws {
        let dir = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try c.url(in: dir)

        let info = try await AVFoundationAudioInspector().inspect(url: source)
        let tracks = [0.0, 10, 20].enumerated().map { i, s in
            ParsedTrack(index: i + 1, start: Timestamp(seconds: s), artists: ["A\(i + 1)"],
                        titles: ["T\(i + 1)"], rawText: "")
        }
        let result = try await ExportJob().run(ExportRequest(
            source: source, sourceInfo: info, tracks: tracks, leadIn: .includeInFirstTrack,
            album: AlbumMetadata(album: "Formats", albumArtist: "DJ", year: nil, genre: nil, artworkJPEG: nil),
            settings: ExportSettings(outputDirectory: dir, folderName: "Formats",
                                     existingFolderPolicy: .fail))) { _ in }

        // A resampled source can't be counted natively; its expected length is the duration at the working rate.
        let sourceFrames = c.resampledFrom == nil ? try await AudioTestSupport.frameCount(source) : info.totalFrames
        let perTrack = try await result.files.asyncMap { try await AudioTestSupport.frameCount($0) }
        let tenSeconds = Int64(c.sampleRate) * 10

        // The cuts land exactly; only when resampling can the final track (which runs to EOF) end a few
        // frames off the nominal length, because the sample-rate converter's tail isn't frame-aligned.
        let slack: Int64 = c.resampledFrom == nil ? 0 : 64
        #expect(perTrack[0] == tenSeconds && perTrack[1] == tenSeconds, "per-track \(perTrack)")
        #expect(abs(perTrack[2] - (sourceFrames - 2 * tenSeconds)) <= slack, "per-track \(perTrack)")
        #expect(abs(perTrack.reduce(0, +) - sourceFrames) <= slack)

        let outInfo = try await AVFoundationAudioInspector().inspect(url: result.files[0])
        #expect(outInfo.codecName == "AAC" && outInfo.sampleRate == c.sampleRate && outInfo.channels == c.channels)
        #expect(try AudioTestSupport.ilst(result.files[1])["pgap"] == Data([1]))
    }

    @Test("encodable sample rate: kept when AAC supports it, otherwise a clean halving or the nearest below",
          arguments: [
            (44_100.0, 44_100.0), (48_000.0, 48_000.0), (22_050.0, 22_050.0),
            (96_000.0, 48_000.0), (88_200.0, 44_100.0), (192_000.0, 48_000.0), (176_400.0, 44_100.0),
            (64_000.0, 32_000.0), (37_800.0, 32_000.0), (50_000.0, 48_000.0), (6_000.0, 8_000.0),
          ])
    func encodableRate(_ input: Double, _ expected: Double) {
        #expect(EncodingSettings.encodableSampleRate(for: input) == expected)
    }

    @Test("AAC bitrate: the full request when the encoder allows it, lowered when it doesn't")
    func bitRateCap() {
        #expect(EncodingSettings.aacBitRate(requestedKbps: 256, sampleRate: 44_100, channels: 2) == 256_000)
        #expect(EncodingSettings.aacBitRate(requestedKbps: 256, sampleRate: 48_000, channels: 1) == 256_000)
        #expect(EncodingSettings.aacBitRate(requestedKbps: 128, sampleRate: 22_050, channels: 2) == 128_000)
        // Low-rate mono can't take 256 kbps; the exact ceiling is the OS encoder's, so only bound it.
        let lowRateMono = EncodingSettings.aacBitRate(requestedKbps: 256, sampleRate: 22_050, channels: 1)
        #expect(lowRateMono > 0 && lowRateMono < 256_000)
    }

    @Test("a non-audio file is rejected at inspection")
    func rejectsGarbage() async throws {
        let dir = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fake = dir.appendingPathComponent("not-audio.wav")
        try Data("this is not a wav".utf8).write(to: fake)
        await #expect(throws: (any Error).self) { try await AVFoundationAudioInspector().inspect(url: fake) }
    }
}
