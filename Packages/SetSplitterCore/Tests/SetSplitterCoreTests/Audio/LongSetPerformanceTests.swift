import Foundation
import Testing
@testable import SetSplitterCore

/// implementation.md §13 Q5/Q6: a 2-hour split should stay well under 200 MB and finish in
/// about two minutes. Opt-in (a 2 h file is too big to commit):
///
///     SETSPLITTER_LONG_FILE=/path/to/two-hour.mp3 swift test --filter LongSet
@Suite("Long set performance (opt-in)")
struct LongSetPerformanceTests {

    private static let path = ProcessInfo.processInfo.environment["SETSPLITTER_LONG_FILE"]

    @Test("2 h split: time and peak memory", .enabled(if: path != nil))
    func splitTwoHours() async throws {
        let source = URL(fileURLWithPath: try #require(Self.path))
        let parent = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let info = try await AVFoundationAudioInspector().inspect(url: source)
        // 40 evenly spaced tracks.
        let step = info.duration / 40
        let tracks = (0..<40).map { i in
            ParsedTrack(index: i + 1, start: Timestamp(seconds: (Double(i) * step).rounded(.down)),
                        artists: ["Artist"], titles: ["Track \(i + 1)"], rawText: "")
        }
        let request = ExportRequest(
            source: source, sourceInfo: info, tracks: tracks, leadIn: .includeInFirstTrack,
            album: AlbumMetadata(album: "Long", albumArtist: "Perf"),
            settings: ExportSettings(outputDirectory: parent, folderName: "Long"))

        let sampler = PeakMemory()
        let started = ContinuousClock.now
        let result = try await ExportJob().run(request) { _ in sampler.sample() }
        let elapsed = started.duration(to: .now)

        let mb = Double(sampler.peak) / 1_048_576
        print("LONGSET duration=\(Int(info.duration))s tracks=\(result.files.count) wall=\(elapsed) peakFootprint=\(String(format: "%.0f", mb)) MB")
        #expect(result.files.count == 40)
        #expect(mb < 200, "peak footprint \(mb) MB exceeds the 200 MB budget")
    }
}

/// Peak `phys_footprint`, sampled from the progress callback (~10 Hz).
private final class PeakMemory: @unchecked Sendable {
    private let lock = NSLock()
    private var _peak: UInt64 = 0
    var peak: UInt64 { lock.withLock { _peak } }
    func sample() {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if kr == KERN_SUCCESS { lock.withLock { _peak = max(_peak, info.phys_footprint) } }
    }
}
