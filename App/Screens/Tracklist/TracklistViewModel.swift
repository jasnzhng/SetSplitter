//
//  TracklistViewModel.swift
//  SetSplitter
//
//  Parsing itself is debounced inside `SessionStore`; this view model is the
//  screen's edit surface (inline edits, paste/clear) and its navigation.
//

import AppKit
import Observation
import SetSplitterCore

@MainActor
@Observable
final class TracklistViewModel {

    let store: SessionStore

    /// The track whose card the pointer is over; the timeline strip mirrors it
    /// and vice versa.
    var highlightedTrackID: UUID?

    init(store: SessionStore) {
        self.store = store
    }

    func setTitle(_ title: String, for track: ParsedTrack) {
        guard title != track.title else { return }
        store.edits.setTitle(title, at: track.start)
    }

    func setArtist(_ artist: String, for track: ParsedTrack) {
        guard artist != track.artist else { return }
        store.edits.setArtist(artist, at: track.start)
    }

    func revert(_ track: ParsedTrack) {
        store.edits.reset(at: track.start)
    }

    func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        store.tracklistText = text
    }

    func clearText() {
        store.tracklistText = ""
        store.edits.resetAll()
    }

    func back() { store.go(to: .importFile) }

    func advance() {
        guard store.canLeaveTracklist else { return }
        store.reparse()   // flush any pending debounce so the export sees the final parse
        store.go(to: .export)
    }
}
