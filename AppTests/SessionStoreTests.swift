import Foundation
import Testing
@testable import SetSplitter
import SetSplitterCore

@MainActor
@Suite("SessionStore")
struct SessionStoreTests {

    @Test("an empty tracklist shows no tracks and no warnings, and does not block")
    func emptyTracklist() {
        let store = Fixtures.store()
        store.tracklistText = "  \n "
        store.reparse()
        #expect(store.tracks.isEmpty)
        #expect(store.warnings.isEmpty)
        #expect(store.canLeaveTracklist)
        #expect(store.exportPlan?.tracks.count == 1)   // one track named after the album
    }

    @Test("pasted text with no timestamps blocks Continue")
    func unparseable() {
        let store = Fixtures.store()
        store.tracklistText = "just some words, no times at all"
        store.reparse()
        #expect(store.hasBlockingWarning)
        #expect(!store.canLeaveTracklist)
    }

    @Test("no source file also blocks Continue")
    func needsSource() {
        #expect(!Fixtures.store(withSource: false).canLeaveTracklist)
    }

    @Test("parsing updates tracks and durations; edits survive a re-parse")
    func editsSurviveReparse() {
        let store = Fixtures.store()
        store.tracklistText = "0:00 A - One\n1:00 B - Two"
        store.reparse()
        #expect(store.tracks.map(\.title) == ["One", "Two"])
        #expect(store.durations == [60, 540])

        store.edits.setTitle("Edited", at: Timestamp(seconds: 60))
        store.tracklistText = "0:00 A - One\n1:00 B - Two\n2:00 C - Three"
        store.reparse()
        #expect(store.tracks.map(\.title) == ["One", "Edited", "Three"])
        #expect(store.tracks[1].userEdited)
    }

    @Test("changing options persists them")
    func optionsPersist() {
        let prefs = StubPreferences()
        let store = Fixtures.store(prefs: prefs)
        store.parseOptions.stripBracketedTags = false
        #expect(prefs.options.stripBracketedTags == false)
    }

    @Test("year: empty is fine, four digits is fine, anything else is invalid")
    func year() {
        let store = Fixtures.store()
        for (text, valid, value) in [("", true, nil), ("2026", true, 2026), (" 1999 ", true, 1999),
                                     ("abc", false, nil), ("20260", false, nil), ("-5", false, nil), ("99", false, nil)] as [(String, Bool, Int?)] {
            store.yearText = text
            #expect(store.yearIsValid == valid, "\(text)")
            #expect(store.year == value, "\(text)")
        }
    }

    @Test("export needs album, artist, folder and a valid year")
    func canExport() throws {
        let store = Fixtures.store()
        #expect(!store.canExport)
        store.albumTitle = "Set"; store.albumArtist = "DJ"
        #expect(!store.canExport)   // no folder yet
        store.outputFolder = OutputFolder(url: try Fixtures.tempDirectory(), access: nil)
        #expect(store.canExport)
        store.yearText = "nope"
        #expect(!store.canExport)
    }

    @Test("album title is guessed from the filename, but never overwrites the user's own")
    func albumGuess() {
        let store = Fixtures.store()
        store.guessAlbumTitle(fromFilename: "Big_Room_2026.mp3")
        #expect(store.albumTitle == "Big Room 2026")
        store.guessAlbumTitle(fromFilename: "Other_Set.mp3")           // still the guess → replaced
        #expect(store.albumTitle == "Other Set")
        store.albumTitle = "My Own Title"
        store.guessAlbumTitle(fromFilename: "Third.mp3")               // user typed → kept
        #expect(store.albumTitle == "My Own Title")
    }

    @Test("folder name is 'Artist - Album', or just the album without an artist")
    func folderName() {
        let store = Fixtures.store()
        store.albumTitle = "Set"
        #expect(store.folderName == "Set")
        store.albumArtist = "DJ"
        #expect(store.folderName == "DJ - Set")
    }

    @Test("startOver clears the session and returns to Import")
    func startOver() {
        let store = Fixtures.store()
        store.tracklistText = "0:00 A - B"; store.reparse()
        store.albumTitle = "X"; store.step = .export
        store.startOver()
        #expect(store.source == nil && store.tracks.isEmpty && store.albumTitle.isEmpty)
        #expect(store.step == .importFile)
    }
}
