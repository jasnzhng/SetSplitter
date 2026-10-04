import Foundation
import Testing
@testable import SetSplitterCore

@Suite("TimestampScanner")
struct TimestampScannerTests {

    private let scanner = TimestampScanner()

    @Test("a wrapped timestamp is consumed with its brackets", arguments: [
        ("[00:28] A - B\n[04:31] C - D", ["A - B", "C - D"]),
        ("(00:28) A - B (04:31) C - D", ["A - B", "C - D"]),
        ("[1:02:03] A - B [1:05:00] C - D", ["A - B", "C - D"]),
    ])
    func wrapperIsConsumed(input: String, expectedTexts: [String]) {
        let texts = scanner.scan(input).map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(texts == expectedTexts)
    }

    @Test("a lone or mismatched bracket next to a timestamp is left alone")
    func mismatchedWrapperIsLeftAlone() {
        let segments = scanner.scan("0:00 A - B [ 3:30 C - D")
        #expect(segments.count == 2)
        #expect(segments[0].text.trimmingCharacters(in: .whitespaces).hasSuffix("["), "an unpaired '[' stays on the previous segment's text")
    }

    @Test("bracketed timestamps parse to clean artists and titles end to end")
    func bracketedTimestampsEndToEnd() {
        let result = TracklistParser().parse(text: "[00:28] SIDEPIECE - WILD [EXPERTS ONLY]\n[04:31] Jamiroquai - Canned Heat (ID Remix) [SONY S2]")
        #expect(result.tracks.map(\.artist) == ["SIDEPIECE", "Jamiroquai"])
        #expect(result.tracks.map(\.title) == ["WILD [EXPERTS ONLY]", "Canned Heat (ID Remix) [SONY S2]"])
    }
}
