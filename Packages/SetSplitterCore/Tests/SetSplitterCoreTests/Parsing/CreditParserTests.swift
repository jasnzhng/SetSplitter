import Testing
@testable import SetSplitterCore

/// The worked-examples table. Each row asserts the structured
/// `artists` / `titles` arrays (never the joined strings). Rows that contain a
/// `W/` join exercise EntrySplitter + CreditParser + TrackAssembler, so every
/// row is checked through the real per-segment path (a `0:00` prefix + the
/// public parser) rather than `CreditParser` in isolation.
@Suite("CreditParser — worked examples")
struct CreditParserWorkedExamplesTests {

    private func parseSegment(_ segment: String, _ options: ParseOptions = .default) -> ParsedTrack {
        let result = TracklistParser().parse(text: "0:00 \(segment)", options: options)
        #expect(result.tracks.count == 1)
        return result.tracks[0]
    }

    @Test("row 1 — ft. on the artist side, remix credit stays in the title")
    func row1() {
        let t = parseSegment("Dom Dolla ft. Daya - Dreamin (Eli Brown Remix)")
        #expect(t.artists == ["Dom Dolla", "Daya"])
        #expect(t.titles == ["Dreamin (Eli Brown Remix)"])
    }

    @Test("row 2 — vs. splits both artist and title sides; mashup paren kept")
    func row2() {
        let t = parseSegment("CamelPhat vs. The Temper Trap - NYP2 vs. Sweet Disposition (House Music Bro & Tyson O'Brien Mashup)")
        #expect(t.artists == ["CamelPhat", "The Temper Trap"])
        #expect(t.titles == ["NYP2", "Sweet Disposition (House Music Bro & Tyson O'Brien Mashup)"])
    }

    @Test("row 3 — W/ mashup with a pipe leader; edit credit stays in the title")
    func row3() {
        let t = parseSegment("Mauro Picotto & Eftihios - Like This, Like That W/ | John Summit ft. HAYLA - Where You Are (John Summit & Maddix Edit)")
        #expect(t.artists == ["Mauro Picotto & Eftihios", "John Summit", "HAYLA"])
        #expect(t.titles == ["Like This, Like That", "Where You Are (John Summit & Maddix Edit)"])
    }

    @Test("row 4 — W/ mashup, second entry carries an Acappella")
    func row4() {
        let t = parseSegment("Vintage Culture - ID W/ | Dom Dolla - San Frandisco (Acappella)")
        #expect(t.artists == ["Vintage Culture", "Dom Dolla"])
        #expect(t.titles == ["ID", "San Frandisco (Acappella)"])
    }

    @Test("row 5 — (feat. X) pulled out of the title, (Extended Mix) left in")
    func row5() {
        let t = parseSegment("Artist - Title (feat. Someone) (Extended Mix)")
        #expect(t.artists == ["Artist", "Someone"])
        #expect(t.titles == ["Title (Extended Mix)"])
    }

    @Test("row 6 — duo name with '&' is never split")
    func row6() {
        let t = parseSegment("Danny Avila & Matt Sassari - Diamonds")
        #expect(t.artists == ["Danny Avila & Matt Sassari"])
        #expect(t.titles == ["Diamonds"])
    }
}

@Suite("CreditParser — behaviour")
struct CreditParserBehaviourTests {

    let parser = CreditParser()

    @Test("no separator → title only, missingArtist warning")
    func noSeparator() {
        let c = parser.parse("Just A Title", options: .default)
        #expect(c.artists.isEmpty)
        #expect(c.titles == ["Just A Title"])
        #expect(c.warnings.contains(.missingArtist))
    }

    @Test("leftmost separator wins; the rest stays in the title")
    func leftmostWins() {
        let c = parser.parse("Artist - Title - Extended", options: .default)
        #expect(c.artists == ["Artist"])
        #expect(c.titles == ["Title - Extended"])
    }

    @Test("A vs. B - Title → two artists, one title")
    func versusArtistsOneTitle() {
        let c = parser.parse("A vs. B - Title", options: .default)
        #expect(c.artists == ["A", "B"])
        #expect(c.titles == ["Title"])
    }

    @Test("A - X vs. Y → one artist, two titles")
    func oneArtistVersusTitles() {
        let c = parser.parse("A - X vs. Y", options: .default)
        #expect(c.artists == ["A"])
        #expect(c.titles == ["X", "Y"])
    }

    @Test("&, and, comma never split the artist side")
    func neverSplitOnAmpersandAndComma() {
        let c = parser.parse("A & B and C, D - Song", options: .default)
        #expect(c.artists == ["A & B and C, D"])
    }

    @Test("title-first order")
    func titleFirst() {
        var opts = ParseOptions.default
        opts.fieldOrder = .titleThenArtist
        let c = parser.parse("Song Name - The Artist", options: opts)
        #expect(c.artists == ["The Artist"])
        #expect(c.titles == ["Song Name"])
    }

    @Test("depth-aware: vs. inside a bootleg credit is not split")
    func versusInsideCreditNotSplit() {
        let c = parser.parse("Artist - Title (A vs. B Bootleg)", options: .default)
        #expect(c.artists == ["Artist"])
        #expect(c.titles == ["Title (A vs. B Bootleg)"])
    }

    @Test("artists deduped case-insensitively, first occurrence kept")
    func dedupeArtists() {
        let c = parser.parse("John Summit ft. john summit - Song", options: .default)
        #expect(c.artists == ["John Summit"])
    }

    @Test("' x ' only splits when the option is on")
    func xSeparatorOptional() {
        let off = parser.parse("Artist A x Artist B - Song", options: .default)
        #expect(off.artists == ["Artist A x Artist B"])

        var on = ParseOptions.default
        on.treatXAsArtistSeparator = true
        let split = parser.parse("Artist A x Artist B - Song", options: on)
        #expect(split.artists == ["Artist A", "Artist B"])
    }

    @Test("ID - ID passes through")
    func idDashId() {
        let c = parser.parse("ID - ID", options: .default)
        #expect(c.artists == ["ID"])
        #expect(c.titles == ["ID"])
    }
}
