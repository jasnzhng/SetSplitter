import Testing
@testable import SetSplitterCore

@Suite("ExportPlanner")
struct ExportPlannerTests {

    private let source = AudioSourceInfo(duration: 100, sampleRate: 1000, channels: 2)

    private func track(_ i: Int, _ start: Double, _ artist: String = "A", _ title: String = "T") -> ParsedTrack {
        ParsedTrack(index: i, start: Timestamp(seconds: start), artists: [artist], titles: [title], rawText: "")
    }

    private func plan(_ tracks: [ParsedTrack], leadIn: ParseOptions.LeadInStrategy = .includeInFirstTrack) -> ExportPlan {
        ExportPlanner().plan(tracks: tracks, source: source, leadIn: leadIn, albumTitle: "My Set")
    }

    @Test("ranges tile the source exactly")
    func tiles() {
        let p = plan([track(1, 0), track(2, 30), track(3, 60.5)])
        #expect(p.tracks.map(\.range) == [0..<30_000, 30_000..<60_500, 60_500..<100_000])
        #expect(p.isContiguous)
        #expect(p.tracks.map(\.trackNumber) == [1, 2, 3])
    }

    @Test("lead-in included: first track is extended back to 0")
    func leadInIncluded() {
        let p = plan([track(1, 10), track(2, 50)])
        #expect(p.tracks[0].range == 0..<50_000)
    }

    @Test("lead-in trimmed: first track starts at its timestamp")
    func leadInTrimmed() {
        let p = plan([track(1, 10), track(2, 50)], leadIn: .trim)
        #expect(p.tracks[0].range == 10_000..<50_000)
        #expect(p.isContiguous)
    }

    @Test("timestamps at or past the end are dropped with a warning")
    func beyondEnd() {
        let p = plan([track(1, 0), track(2, 100), track(3, 500)])
        #expect(p.tracks.count == 1)
        #expect(p.tracks[0].range == 0..<100_000)
        #expect(p.warnings.count == 2)
        #expect(p.warnings.contains(.startBeyondSourceDuration(Timestamp(seconds: 500))))
    }

    @Test("empty tracklist → one track named after the album")
    func emptyTracklist() {
        let p = plan([])
        #expect(p.tracks.count == 1)
        #expect(p.tracks[0].range == 0..<100_000)
        #expect(p.tracks[0].displayTitle == "My Set")
        #expect(p.tracks[0].filename == "01 My Set.m4a")
    }

    @Test("out-of-order and duplicate starts are normalised")
    func ordering() {
        let p = plan([track(1, 0, "A", "one"), track(2, 60, "B", "three"), track(3, 30, "C", "two"), track(4, 30, "D", "dupe")])
        #expect(p.tracks.map(\.displayTitle) == ["one", "two", "three"])
        #expect(p.tracks.map(\.trackNumber) == [1, 2, 3])
        #expect(p.isContiguous)
    }

    @Test("colliding filenames are uniqued")
    func filenames() {
        let p = plan([track(1, 0, "A", "Same"), track(2, 50, "A", "Same")])
        #expect(p.tracks[0].filename == "01 A - Same.m4a")
        #expect(p.tracks[1].filename == "02 A - Same.m4a")   // numbers differ, so no suffix needed
    }

    @Test("a last track under 5 s gets a warning")
    func shortLast() {
        let p = plan([track(1, 0), track(2, 97)])
        #expect(p.tracks[1].track.warnings.contains(.trackShorterThanFiveSeconds))
        #expect(!p.tracks[0].track.warnings.contains(.trackShorterThanFiveSeconds))
    }

    @Test("empty title falls back to Track N")
    func emptyTitle() {
        let t = ParsedTrack(index: 1, start: Timestamp(seconds: 0), artists: [], titles: [], rawText: "")
        let p = plan([t])
        #expect(p.tracks[0].displayTitle == "Track 1")
    }
}
