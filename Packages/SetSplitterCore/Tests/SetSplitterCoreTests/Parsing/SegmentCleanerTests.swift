import Testing
@testable import SetSplitterCore

@Suite("SegmentCleaner — one pair per rule")
struct SegmentCleanerTests {

    let cleaner = SegmentCleaner()

    @Test("cleaning rules", arguments: [
        // (input, expected, note)
        ("| Belocca - Ifuna (Intro Edit)", "Belocca - Ifuna (Intro Edit)"),        // pipe leader
        ("01. Artist - Title", "Artist - Title"),                                    // "01." numbering
        ("1) Artist - Title", "Artist - Title"),                                     // "1)" numbering
        ("#3. Artist - Title", "Artist - Title"),                                    // "#3." numbering
        ("[12] Artist - Title", "Artist - Title"),                                   // "[12]" numbering
        ("1 - Artist - Title", "Artist - Title"),                                    // "1 -" numbering
        ("• Artist - Title", "Artist - Title"),                                      // bullet leader
        ("Artist - Title 02.", "Artist - Title"),                                    // trailing next-entry number
        ("Artist - Title 12)", "Artist - Title"),                                    // trailing next-entry number, paren
        ("Artist  -   Title", "Artist - Title"),                                     // whitespace collapse
        ("Artist - Song (Eli Brown Remix)", "Artist - Song (Eli Brown Remix)"),      // musical paren kept
    ])
    func rule(_ input: String, _ expected: String) {
        #expect(cleaner.clean(input, options: .default) == expected)
    }
}

@Suite("EntrySplitter")
struct EntrySplitterTests {

    let splitter = EntrySplitter()

    @Test("splits on W/")
    func splitsOnSlashW() {
        #expect(splitter.split("A - X W/ B - Y") == ["A - X", "B - Y"])
    }

    @Test("splits on lowercase w/")
    func splitsOnLowercaseW() {
        #expect(splitter.split("A - X w/ B - Y") == ["A - X", "B - Y"])
    }

    @Test("spelled 'with' splits only before a pipe leader")
    func spelledWithBeforePipe() {
        #expect(splitter.split("A - X With | B - Y") == ["A - X", "| B - Y"])
        #expect(splitter.split("A - Song with Friends") == ["A - Song with Friends"])
    }

    @Test("no marker → single entry")
    func noMarker() {
        #expect(splitter.split("A - X") == ["A - X"])
    }

    @Test("W/ inside parentheses is not a split point")
    func slashWInsideParens() {
        #expect(splitter.split("A - X (mix w/ vocal)") == ["A - X (mix w/ vocal)"])
    }
}
