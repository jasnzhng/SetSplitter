import Testing
@testable import SetSplitterCore

@Suite("TracklistParser — validation & edges")
struct TracklistParserTests {

    let parser = TracklistParser()

    // MARK: newline independence

    @Test("one line and many lines parse identically")
    func newlineIndependence() {
        let oneLine = "0:00 A - X 2:00 B - Y 4:00 C - Z"
        let manyLines = "0:00 A - X\n2:00 B - Y\n4:00 C - Z"
        let a = parser.parse(text: oneLine).tracks.map { [$0.artist, $0.title] }
        let b = parser.parse(text: manyLines).tracks.map { [$0.artist, $0.title] }
        #expect(a == b)
        #expect(a == [["A", "X"], ["B", "Y"], ["C", "Z"]])
    }

    // MARK: normalisation

    @Test("CRLF, non-breaking space and zero-width characters are normalised")
    func normalisation() {
        let messy = "0:00\u{00A0}Artist\u{200B} - Title\r\n2:30 Other - Thing"
        let tracks = parser.parse(text: messy).tracks
        #expect(tracks.count == 2)
        #expect(tracks[0].artist == "Artist")
        #expect(tracks[0].title == "Title")
    }

    // MARK: no timestamps

    @Test("no timestamps → zero tracks, blocking warning")
    func noTimestamps() {
        let result = parser.parse(text: "just some\nlines of text\nno times here")
        #expect(result.tracks.isEmpty)
        #expect(result.warnings.contains(.noTimestampsFound))
        #expect(result.warnings.contains(.noTracksParsed))
        #expect(result.allWarnings.contains { $0.isBlocking })
    }

    @Test("empty input → zero tracks, no crash")
    func emptyInput() {
        #expect(parser.parse(text: "").tracks.isEmpty)
        #expect(parser.parse(text: "   \n  ").tracks.isEmpty)
    }

    // MARK: first timestamp not zero

    @Test("first timestamp not 0:00 → document warning, start preserved")
    func firstNotZero() {
        let result = parser.parse(text: "1:30 A - X 4:00 B - Y")
        #expect(result.tracks.first?.start == Timestamp(seconds: 90))
        #expect(result.warnings.contains { if case .firstTimestampNotZero = $0 { return true } else { return false } })
    }

    // MARK: monotonicity

    @Test("non-increasing timestamp → warning on the offending track")
    func nonMonotonic() {
        let result = parser.parse(text: "0:00 A - X 5:00 B - Y 3:00 C - Z")
        #expect(result.tracks.count == 3)
        #expect(result.tracks[2].warnings.contains(.timestampNotIncreasing))
        #expect(!result.tracks[1].warnings.contains(.timestampNotIncreasing))
    }

    @Test("duplicate timestamp → later one dropped, warned once")
    func duplicateTimestamp() {
        let result = parser.parse(text: "0:00 A - X 2:00 B - Y 2:00 C - Z 4:00 D - W")
        #expect(result.tracks.map(\.title) == ["X", "Y", "W"])
        #expect(result.tracks.map(\.index) == [1, 2, 3])
        #expect(result.warnings.contains { if case .duplicateTimestamp = $0 { return true } else { return false } })
    }

    // MARK: short track

    @Test("gap under 5 s → short-track warning on the earlier track")
    func shortTrack() {
        let result = parser.parse(text: "0:00 A - X 0:03 B - Y 3:00 C - Z")
        #expect(result.tracks[0].warnings.contains(.trackShorterThanFiveSeconds))
        #expect(!result.tracks[1].warnings.contains(.trackShorterThanFiveSeconds))
    }

    // MARK: mashup strategy

    @Test("mashupStrategy .firstEntryOnly drops entries after the first")
    func firstEntryOnly() {
        var opts = ParseOptions.default
        opts.mashupStrategy = .firstEntryOnly
        let result = parser.parse(text: "0:00 A - X W/ B - Y", options: opts)
        #expect(result.tracks.count == 1)
        #expect(result.tracks[0].artists == ["A"])
        #expect(result.tracks[0].titles == ["X"])
    }

    @Test("mashupStrategy .merge keeps everything (default)")
    func mergeStrategy() {
        let result = parser.parse(text: "0:00 A - X W/ B - Y")
        #expect(result.tracks[0].artists == ["A", "B"])
        #expect(result.tracks[0].titles == ["X", "Y"])
    }

    // MARK: bracketed tags

    @Test("stripBracketedTags off keeps [Free Download]")
    func keepBracketedTags() {
        var opts = ParseOptions.default
        opts.stripBracketedTags = false
        let result = parser.parse(text: "0:00 Artist - Song [Free Download]", options: opts)
        #expect(result.tracks[0].title == "Song [Free Download]")
    }

    @Test("stripBracketedTags on removes [Free Download] but keeps (Original Mix)")
    func stripBracketedTagsDefault() {
        let result = parser.parse(text: "0:00 Artist - Song (Original Mix) [Free Download]")
        #expect(result.tracks[0].title == "Song (Original Mix)")
    }

    // MARK: W/ edge cases

    @Test("W/ with no ' - ' of its own → extra title, no extra artist")
    func mashupBareTail() {
        let result = parser.parse(text: "0:00 Vintage Culture - ID W/ Acappella")
        #expect(result.tracks[0].artists == ["Vintage Culture"])
        #expect(result.tracks[0].titles == ["ID", "Acappella"])
    }

    @Test("same artist on both sides of W/ → deduped")
    func mashupDedupeArtist() {
        let result = parser.parse(text: "0:00 John Summit - A W/ John Summit ft. HAYLA - B")
        #expect(result.tracks[0].artists == ["John Summit", "HAYLA"])
        #expect(result.tracks[0].titles == ["A", "B"])
    }

    // MARK: missing artist

    @Test("entry with no separator → title only, missingArtist warning on the track")
    func missingArtist() {
        let result = parser.parse(text: "0:00 Just A Mystery Track")
        #expect(result.tracks[0].artists.isEmpty)
        #expect(result.tracks[0].titles == ["Just A Mystery Track"])
        #expect(result.tracks[0].warnings.contains(.missingArtist))
    }

    // MARK: rawText

    @Test("rawText keeps the segment as pasted")
    func rawTextPreserved() {
        let result = parser.parse(text: "0:00  |  Artist  -  Title  ")
        #expect(result.tracks[0].rawText == "|  Artist  -  Title")
        #expect(result.tracks[0].artist == "Artist")
    }
}
