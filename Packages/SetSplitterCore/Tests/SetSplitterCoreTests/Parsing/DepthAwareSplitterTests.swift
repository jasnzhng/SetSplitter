import Testing
@testable import SetSplitterCore

@Suite("DepthAwareSplitter")
struct DepthAwareSplitterTests {

    let splitter = DepthAwareSplitter()

    // MARK: firstSplit

    @Test("splits on the first depth-0 separator")
    func firstSplitBasic() {
        let m = splitter.firstSplit(of: [" - "], in: "Dom Dolla - Dreamin", wholeWord: false)
        #expect(m?.head == "Dom Dolla")
        #expect(m?.tail == "Dreamin")
    }

    @Test("ignores separators inside parentheses")
    func firstSplitInsideParens() {
        // The " - " inside "(Intro - Edit)" must not be the split point.
        let m = splitter.firstSplit(of: [" - "], in: "Belocca - Ifuna (Intro - Edit)", wholeWord: false)
        #expect(m?.head == "Belocca")
        #expect(m?.tail == "Ifuna (Intro - Edit)")
    }

    @Test("ignores separators inside brackets")
    func firstSplitInsideBrackets() {
        let m = splitter.firstSplit(of: [" vs "], in: "A [B vs C] vs D", wholeWord: true)
        #expect(m?.head == "A [B vs C]")
        #expect(m?.tail == "D")
    }

    @Test("no match returns nil")
    func firstSplitNoMatch() {
        #expect(splitter.firstSplit(of: [" - "], in: "No separator here", wholeWord: false) == nil)
    }

    @Test("whole-word: 'vs' does not match inside 'Elvis'")
    func wholeWordBoundary() {
        #expect(splitter.firstSplit(of: ["vs"], in: "Elvis Presley", wholeWord: true) == nil)
        #expect(splitter.firstSplit(of: ["vs"], in: "A vs B", wholeWord: true)?.head == "A ")
    }

    @Test("whole-word: dotted token needs no right boundary ('feat.Daya')")
    func dottedTokenNoRightBoundary() {
        let m = splitter.firstSplit(of: ["feat."], in: "Artist feat.Daya", wholeWord: true)
        #expect(m?.head == "Artist ")
        #expect(m?.tail == "Daya")
    }

    @Test("case-insensitive")
    func caseInsensitive() {
        #expect(splitter.firstSplit(of: ["vs"], in: "A VS B", wholeWord: true)?.tail == " B")
        #expect(splitter.firstSplit(of: ["w/"], in: "A W/ B", wholeWord: false)?.tail == " B")
    }

    @Test("earlier array entry wins at the same position")
    func priorityOrder() {
        let m = splitter.firstSplit(of: ["feat.", "feat"], in: "A feat. B", wholeWord: true)
        #expect(m?.separatorIndex == 0)
        #expect(m?.separator == "feat.")
    }

    // MARK: unbalanced degradation (§9)

    @Test("unbalanced parens degrade to depth 0 — split still happens")
    func unbalancedParensDegrade() {
        // Trailing "(" is never closed. A naive depth scan would treat
        // everything after it as depth > 0 and refuse to split.
        let m = splitter.firstSplit(of: [" - "], in: "Artist (note - Title", wholeWord: false)
        #expect(m?.head == "Artist (note")
        #expect(m?.tail == "Title")
    }

    @Test("stray closing paren does not go negative / swallow the rest")
    func strayCloseParen() {
        let parts = splitter.allComponents(splittingOn: [" vs "], in: "A) vs B vs C", wholeWord: true)
        #expect(parts == ["A)", "B", "C"])
    }

    // MARK: allComponents

    @Test("allComponents splits every depth-0 occurrence")
    func allComponentsBasic() {
        let parts = splitter.allComponents(splittingOn: [" vs "], in: "A vs B vs C", wholeWord: true)
        #expect(parts == ["A", "B", "C"])
    }

    @Test("allComponents keeps parenthesised separators intact")
    func allComponentsRespectsParens() {
        let parts = splitter.allComponents(
            splittingOn: [" vs ", " vs. "],
            in: "NYP2 vs. Sweet Disposition (House Music Bro vs Tyson O'Brien Mashup)",
            wholeWord: true
        )
        #expect(parts == ["NYP2", "Sweet Disposition (House Music Bro vs Tyson O'Brien Mashup)"])
    }

    @Test("allComponents returns the whole string when nothing matches")
    func allComponentsNoMatch() {
        #expect(splitter.allComponents(splittingOn: [" - "], in: "solo", wholeWord: false) == ["solo"])
    }
}
