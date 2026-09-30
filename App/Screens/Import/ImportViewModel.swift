//
//  ImportViewModel.swift
//  SetSplitter
//
//  Loads and validates the dropped/browsed audio file. Talks to Core only
//  through `AudioInspecting`.
//

import Foundation
import Observation
import SetSplitterCore

@MainActor
@Observable
final class ImportViewModel {

    enum Phase: Equatable {
        case idle
        case loading(filename: String)
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    private let store: SessionStore
    private let inspector: any AudioInspecting
    private let picker: any FilePicking

    init(store: SessionStore, inspector: any AudioInspecting, picker: any FilePicking) {
        self.store = store
        self.inspector = inspector
        self.picker = picker
    }

    /// `⌘O` / "Browse…".
    func browse() async {
        guard let url = await picker.chooseAudioFile() else { return }
        await load(url)
    }

    /// Drop handler. Only one file is accepted (§10).
    func handleDrop(_ urls: [URL]) async -> Bool {
        guard urls.count == 1, let url = urls.first else {
            phase = .failed("Drop a single \(SupportedAudio.displayName) file.")
            return false
        }
        await load(url)
        return true
    }

    func load(_ url: URL) async {
        guard SupportedAudio.accepts(url) else {
            phase = .failed("“\(url.lastPathComponent)” isn't an \(SupportedAudio.displayName) file.")
            return
        }
        phase = .loading(filename: url.lastPathComponent)
        // Hold sandbox access from now until the export ends.
        let access = SecurityScopedAccess(url: url)
        do {
            let info = try await inspector.inspect(url: url)
            let isNewFile = store.source?.url != url
            store.source = SourceFile(url: url, info: info, access: access)
            if isNewFile, store.albumTitle.isEmpty {
                store.albumTitle = AlbumNameGuesser.guess(fromFilename: url.lastPathComponent)
            }
            store.exportState = .idle
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// "Choose another file": back to the empty drop zone.
    func clear() {
        store.source = nil
        phase = .idle
    }

    func advance() {
        guard store.source != nil else { return }
        store.go(to: .tracklist)
    }
}
