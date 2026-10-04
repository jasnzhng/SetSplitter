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
    private var loadSequence = 0

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

    /// Drop handler. Only one file is accepted.
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
        // Only the most recent load may publish: two quick drops can finish out of order.
        loadSequence += 1
        let ticket = loadSequence
        phase = .loading(filename: url.lastPathComponent)
        // Hold sandbox access from now until the export ends.
        let access = SecurityScopedAccess(url: url)
        do {
            let info = try await inspector.inspect(url: url)
            guard ticket == loadSequence else { return }
            if store.source?.url != url {
                store.edits.resetAll()   // edits belong to the previous file's tracklist
            }
            store.source = SourceFile(url: url, info: info, access: access)
            store.guessAlbumTitle(fromFilename: url.lastPathComponent)
            store.exportState = .idle
            phase = .idle
        } catch {
            guard ticket == loadSequence else { return }
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
