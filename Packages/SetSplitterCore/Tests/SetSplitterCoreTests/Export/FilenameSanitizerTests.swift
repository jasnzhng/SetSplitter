import Testing
@testable import SetSplitterCore

@Suite("FilenameSanitizer")
struct FilenameSanitizerTests {

    @Test("component sanitising", arguments: [
        ("AC/DC", "AC-DC"),
        ("Re: Stacks", "Re- Stacks"),
        ("  spaced   out  ", "spaced out"),
        (".hidden", "hidden"),
        ("trailing.", "trailing"),
        ("tab\there", "tab here"),
        ("zero\u{200B}width", "zerowidth"),
        ("nul\u{0}byte", "nulbyte"),
        ("Say \"hi\" 🎧", "Say \"hi\" 🎧"),
        ("back\\slash", "back-slash"),
    ])
    func sanitize(input: String, expected: String) {
        #expect(FilenameSanitizer.sanitize(input) == expected)
    }

    @Test("template layouts")
    func templates() {
        #expect(FilenameSanitizer.filename(number: 1, artist: "Dom Dolla", title: "Dreamin", template: .numberArtistTitle)
                == "01 Dom Dolla - Dreamin.m4a")
        #expect(FilenameSanitizer.filename(number: 12, artist: "", title: "ID", template: .numberArtistTitle)
                == "12 ID.m4a")
        #expect(FilenameSanitizer.filename(number: 3, artist: "X", title: "Y", template: .numberTitle)
                == "03 Y.m4a")
    }

    @Test("long names truncate to the byte budget and keep the extension")
    func truncation() {
        let long = String(repeating: "é", count: 300)
        let name = FilenameSanitizer.filename(number: 1, artist: "A", title: long, template: .numberArtistTitle)
        #expect(name.utf8.count <= FilenameSanitizer.maxBytes)
        #expect(name.hasSuffix(".m4a"))
        // Never cuts inside a multi-byte character.
        #expect(String(validatingUTF8: name) != nil)
    }

    @Test("emoji graphemes are not split by truncation")
    func emojiTruncation() {
        let long = String(repeating: "👨‍👩‍👧", count: 100)
        let name = FilenameSanitizer.filename(number: 1, artist: "", title: long, template: .numberTitle)
        #expect(name.utf8.count <= FilenameSanitizer.maxBytes)
        let stem = String(name.dropLast(4))
        #expect(stem.dropFirst(3).allSatisfy { $0 == "👨‍👩‍👧" })
    }

    @Test("collisions get (2), (3) suffixes, case-insensitively")
    func uniquing() {
        let out = FilenameSanitizer.uniqued(["a.m4a", "A.m4a", "b.m4a", "a.m4a"])
        #expect(out == ["a.m4a", "A (2).m4a", "b.m4a", "a (3).m4a"])
    }
}
