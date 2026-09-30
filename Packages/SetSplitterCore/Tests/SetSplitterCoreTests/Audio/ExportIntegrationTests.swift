import AVFoundation
import Foundation
import Testing
@testable import SetSplitterCore

/// implementation.md §9 "Audio integration": real MP3 → three m4a files.
@Suite("Export integration (real audio)", .serialized)
struct ExportIntegrationTests {

    private let source = AudioTestSupport.fixture("short-set.mp3")

    private func tracks(at starts: [Double]) -> [ParsedTrack] {
        starts.enumerated().map { i, s in
            ParsedTrack(index: i + 1, start: Timestamp(seconds: s), artists: ["Artist \(i + 1)"],
                        titles: ["Title \(i + 1)"], rawText: "")
        }
    }

    private func request(
        parent: URL, info: AudioSourceInfo, starts: [Double] = [0, 10, 20],
        leadIn: ParseOptions.LeadInStrategy = .includeInFirstTrack,
        artwork: Data? = nil, policy: ExportSettings.ExistingFolderPolicy = .fail
    ) -> ExportRequest {
        ExportRequest(
            source: source, sourceInfo: info, tracks: tracks(at: starts), leadIn: leadIn,
            album: AlbumMetadata(album: "Test Set", albumArtist: "DJ Test", year: 2026, genre: "Electronic",
                                 artworkJPEG: artwork),
            settings: ExportSettings(outputDirectory: parent, folderName: "DJ Test - Test Set", existingFolderPolicy: policy))
    }

    @Test("splits into gapless tracks: frame counts, seams, metadata, folder layout")
    func endToEnd() async throws {
        let parent = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let info = try await AVFoundationAudioInspector().inspect(url: source)
        #expect(info.sampleRate == 44100 && info.channels == 2 && info.codecName == "MP3")

        let art = try ArtworkPreparer().prepare(TestImages.png(width: 600, height: 600)).jpeg
        let events = ProgressLog()
        let result = try await ExportJob().run(request(parent: parent, info: info, artwork: art)) { events.add($0) }

        // Folder layout: three m4a + cover.jpg, and the temp folder is gone.
        let listing = try FileManager.default.contentsOfDirectory(atPath: result.folder.path).sorted()
        #expect(listing == ["01 Artist 1 - Title 1.m4a", "02 Artist 2 - Title 2.m4a", "03 Artist 3 - Title 3.m4a", "cover.jpg"])
        let parentListing = try FileManager.default.contentsOfDirectory(atPath: parent.path)
        #expect(parentListing == ["DJ Test - Test Set"], "no stray temp folder: \(parentListing)")

        // Frame counts sum exactly to the source, per-track lengths are the requested ones.
        let src = try await AudioTestSupport.decode(source)
        let outs = try await result.files.asyncMap { try await AudioTestSupport.decode($0) }
        let total = outs.reduce(0) { $0 + $1.samples.count / $1.channels }
        #expect(total == src.samples.count / src.channels, "concatenated frames must equal source frames")
        #expect(outs.map { $0.samples.count / 2 } == [441_000, 441_000, src.samples.count / 2 - 882_000])

        // Seam continuity. AAC is lossy, so the decode never equals the source, and each track's
        // encoder starts from silence, giving a brief (~256-frame) warm-up transient at the start of
        // every track. Measured on this fixture: error ≈0.001 up to the seam, ≈0.17 in the first
        // 256 frames after it, ≈0.01 steady state. These are identical (0.16799 / 0.04675) to what the
        // Phase 0 spike reports for the same file — the output Jason confirmed audibly gapless in
        // Music — so the port is faithful. Assert three things:
        //   1. alignment before the seam (a dropped/duplicated frame would wreck the exact-ish tail),
        //   2. alignment after the warm-up (a shifted cut would never settle),
        //   3. no click: the sample-to-sample step at the seam is within the signal's normal range.
        let concat = outs.flatMap(\.samples)
        func maxError(_ frames: Range<Int>) -> Float {
            var m: Float = 0
            for i in (frames.lowerBound * 2)..<(frames.upperBound * 2) { m = max(m, abs(concat[i] - src.samples[i])) }
            return m
        }
        func maxStep(_ frames: Range<Int>) -> Float {
            var m: Float = 0
            for i in frames { m = max(m, abs(concat[i * 2] - concat[(i - 1) * 2])) }
            return m
        }
        for seam in [441_000, 882_000] {
            #expect(maxError((seam - 4096)..<seam) < 0.02, "tail before seam \(seam) is misaligned")
            #expect(maxError((seam + 1024)..<(seam + 4096)) < 0.05, "audio after seam \(seam) is misaligned")
            let step = maxStep(seam..<(seam + 1))
            let typical = max(maxStep((seam - 2000)..<(seam - 100)), maxStep((seam + 100)..<(seam + 2000)))
            #expect(step <= typical * 2,   // a real click is a jump to full scale; this leaves headroom for encoder updates
                     "click at seam \(seam): step \(step) vs typical \(typical)")
        }

        // Metadata, from raw ilst bytes.
        let tags = try AudioTestSupport.ilst(result.files[1])
        #expect(tags["trkn"] == Data([0, 0, 0, 2, 0, 3, 0, 0]))
        #expect(tags["disk"] == Data([0, 0, 0, 1, 0, 1, 0, 0]))
        #expect(tags["pgap"] == Data([1]))
        #expect(String(decoding: tags["aART"] ?? Data(), as: UTF8.self) == "DJ Test")
        #expect(String(decoding: tags["\u{00A9}alb"] ?? Data(), as: UTF8.self) == "Test Set")
        #expect(String(decoding: tags["\u{00A9}nam"] ?? Data(), as: UTF8.self) == "Title 2")
        #expect(String(decoding: tags["\u{00A9}ART"] ?? Data(), as: UTF8.self) == "Artist 2")
        #expect(String(decoding: tags["\u{00A9}day"] ?? Data(), as: UTF8.self) == "2026")
        #expect(tags["covr"] == art, "artwork bytes embedded verbatim")
        #expect(try Data(contentsOf: #require(result.coverURL)) == art)

        // Progress is monotonic, throttled, and ends at done.
        let fractions = events.all.map(\.fraction)
        #expect(fractions == fractions.sorted())
        #expect(events.all.last?.phase == .done)
        #expect(events.all.count < 200)
    }

    @Test("trim lead-in drops audio before the first timestamp")
    func trimLeadIn() async throws {
        let parent = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let info = try await AVFoundationAudioInspector().inspect(url: source)
        let result = try await ExportJob().run(request(parent: parent, info: info, starts: [5, 15], leadIn: .trim))
        let outs = try await result.files.asyncMap { try await AudioTestSupport.decode($0) }
        let frames = outs.map { $0.samples.count / 2 }
        #expect(frames[0] == 441_000)
        #expect(frames[0] + frames[1] == Int(info.totalFrames) - 220_500)
    }

    @Test("existing folder: fail throws, keepBoth suffixes, replace overwrites")
    func existingFolder() async throws {
        let parent = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let info = try await AVFoundationAudioInspector().inspect(url: source)
        _ = try await ExportJob().run(request(parent: parent, info: info, starts: [0, 10]))

        await #expect(throws: ExportError.self) {
            _ = try await ExportJob().run(request(parent: parent, info: info, starts: [0, 10]))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).count == 1, "failed export leaves no temp folder")

        let both = try await ExportJob().run(request(parent: parent, info: info, starts: [0, 10], policy: .keepBoth))
        #expect(both.folder.lastPathComponent == "DJ Test - Test Set (2)")

        let replaced = try await ExportJob().run(request(parent: parent, info: info, starts: [0, 10, 20], policy: .replace))
        #expect(replaced.folder.lastPathComponent == "DJ Test - Test Set")
        #expect(try FileManager.default.contentsOfDirectory(atPath: replaced.folder.path).count == 3)
    }

    @Test("cancelling mid-write throws CancellationError and removes open writers and the temp folder")
    func cancellation() async throws {
        let parent = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let info = try await AVFoundationAudioInspector().inspect(url: source)
        let req = request(parent: parent, info: info)

        // Cancel from inside the progress callback once track 2 is being written, so a writer is
        // open and track 1 is already finished — the cleanup path §7.7 is about.
        let trigger = CancelTrigger()
        let task = Task {
            try await ExportJob().run(req) { p in
                if p.currentTrack >= 2, p.framesProcessed > 0 { trigger.fire() }
            }
        }
        trigger.task = task
        await #expect(throws: CancellationError.self) { _ = try await task.value }
        #expect(trigger.fired, "the export finished before the cancel could land")
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
    }

    @Test("empty tracklist exports one track named after the album")
    func emptyTracklist() async throws {
        let parent = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let info = try await AVFoundationAudioInspector().inspect(url: source)
        let result = try await ExportJob().run(request(parent: parent, info: info, starts: []))
        #expect(result.files.map(\.lastPathComponent) == ["01 Test Set.m4a"])
        let out = try await AudioTestSupport.decode(result.files[0])
        #expect(out.samples.count / 2 == Int(info.totalFrames))
    }
}

// MARK: - helpers

/// Lets a progress callback cancel the task that is running it.
private final class CancelTrigger: @unchecked Sendable {
    private let lock = NSLock()
    private var _task: Task<ExportResult, Error>?
    private var _fired = false
    var task: Task<ExportResult, Error>? {
        get { lock.withLock { _task } }
        set { lock.withLock { _task = newValue } }
    }
    var fired: Bool { lock.withLock { _fired } }
    func fire() {
        let t: Task<ExportResult, Error>? = lock.withLock { _fired = true; return _task }
        t?.cancel()
    }
}

private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [ExportProgress] = []
    func add(_ e: ExportProgress) { lock.lock(); events.append(e); lock.unlock() }
    var all: [ExportProgress] { lock.lock(); defer { lock.unlock() }; return events }
}

extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var out: [T] = []
        for e in self { out.append(try await transform(e)) }
        return out
    }
}
