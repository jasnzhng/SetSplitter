import Testing
@testable import SetSplitterCore

@Suite("TrackEdits, TrackTiming, AlbumNameGuesser")
struct TrackEditsTests {

    private func track(_ start: Double, artists: [String] = ["A"], titles: [String] = ["T"]) -> ParsedTrack {
        ParsedTrack(index: 1, start: Timestamp(seconds: start), artists: artists, titles: titles, rawText: "")
    }

    @Test("edits apply by timestamp and mark the track userEdited")
    func apply() {
        var edits = TrackEdits()
        edits.setTitle("Fixed", at: Timestamp(seconds: 30))
        let out = edits.applying(to: [track(0), track(30)])
        #expect(out[0].title == "T" && !out[0].userEdited)
        #expect(out[1].title == "Fixed" && out[1].userEdited)
        #expect(out[1].artist == "A")
    }

    @Test("edits survive a re-parse that mints new track ids")
    func surviveReparse() {
        var edits = TrackEdits()
        edits.setArtist("Me", at: Timestamp(seconds: 30))
        let first = edits.applying(to: [track(30)])
        let second = edits.applying(to: [track(30, artists: ["Different"])])
        #expect(first[0].artist == "Me" && second[0].artist == "Me")
        #expect(first[0].id != second[0].id)
    }

    @Test("an edit whose timestamp vanished is ignored but retained")
    func vanished() {
        var edits = TrackEdits()
        edits.setTitle("X", at: Timestamp(seconds: 99))
        #expect(edits.applying(to: [track(0)])[0].title == "T")
        #expect(edits.applying(to: [track(99)])[0].title == "X")
    }

    @Test("editing the artist clears the missing-artist warning; reset restores")
    func warningsAndReset() {
        var t = track(0, artists: [])
        t.warnings = [.missingArtist]
        var edits = TrackEdits()
        edits.setArtist("New", at: t.start)
        #expect(edits.applying(to: [t])[0].warnings.isEmpty)
        edits.reset(at: t.start)
        #expect(edits.applying(to: [t])[0].warnings == [.missingArtist])
        #expect(edits.isEmpty)
    }

    @Test("clearing a field yields an empty array, not [\"\"]")
    func clearing() {
        var edits = TrackEdits()
        edits.setArtist("   ", at: Timestamp(seconds: 0))
        #expect(edits.applying(to: [track(0)])[0].artists == [])
    }

    @Test("durations are next.start − start, last runs to the end, never negative")
    func durations() {
        let d = TrackTiming.durations(of: [track(0), track(60), track(200)], sourceDuration: 300)
        #expect(d == [60, 140, 100])
        #expect(TrackTiming.durations(of: [track(400)], sourceDuration: 300) == [0])
    }

    @Test("album name guess", arguments: [
        ("Tomorrowland_2026 Mainstage.mp3", "Tomorrowland 2026 Mainstage"),
        ("  spaced   name .mp3", "spaced name"),
        ("noext", "noext"),
    ])
    func album(input: String, expected: String) {
        #expect(AlbumNameGuesser.guess(fromFilename: input) == expected)
    }
}
