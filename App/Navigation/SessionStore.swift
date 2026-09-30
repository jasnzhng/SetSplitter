//
//  SessionStore.swift
//  SetSplitter
//
//  implementation.md §10. The single source of truth across the three screens.
//  View models read and write it; it owns no AVFoundation and no UI.
//

import Foundation
import Observation
import SetSplitterCore

@MainActor
@Observable
final class SessionStore {

    // MARK: Flow

    var step: AppFlow.Step = .importFile

    // MARK: Import

    var source: SourceFile?

    // MARK: Tracklist

    var tracklistText = "" {
        didSet { if tracklistText != oldValue { scheduleReparse() } }
    }

    var parseOptions: ParseOptions {
        didSet {
            guard parseOptions != oldValue else { return }
            preferences.saveParseOptions(parseOptions)
            scheduleReparse()
        }
    }

    private(set) var parseResult = ParseResult()

    /// Manual corrections, layered over each re-parse (keyed by timestamp).
    var edits = TrackEdits()

    // MARK: Album

    var albumTitle = ""
    var albumArtist = ""
    var yearText = String(Calendar.current.component(.year, from: .now))
    var genre: String {
        didSet { if genre != oldValue { preferences.saveGenre(genre) } }
    }
    var comment = ""
    var isCompilation = false
    var artwork: Artwork?

    // MARK: Export

    var outputFolder: OutputFolder?
    var existingFolderPolicy: ExportSettings.ExistingFolderPolicy = .fail
    var exportState: ExportState = .idle

    // MARK: Dependencies

    private let preferences: any PreferencesStoring
    private let parser = TracklistParser()
    private var reparseTask: Task<Void, Never>?

    init(preferences: any PreferencesStoring) {
        self.preferences = preferences
        self.parseOptions = preferences.loadParseOptions()
        self.genre = preferences.loadGenre() ?? "Electronic"
        if let access = preferences.loadOutputFolder() {
            self.outputFolder = OutputFolder(url: access.url, access: access)
        }
    }

    // MARK: Derived

    /// Parser output with the user's inline edits applied.
    var tracks: [ParsedTrack] { edits.applying(to: parseResult.tracks) }

    /// Seconds per track, aligned with `tracks`.
    var durations: [Double] {
        TrackTiming.durations(of: tracks, sourceDuration: source?.info.duration ?? 0)
    }

    /// Every warning worth showing under the preview, document-level first.
    var warnings: [ParseWarning] {
        parseResult.warnings + tracks.flatMap(\.warnings)
    }

    var hasBlockingWarning: Bool { warnings.contains(where: \.isBlocking) }

    /// An empty tracklist is legal (§14: exports one track named after the
    /// album). Only a pasted-but-unparseable one blocks.
    var canLeaveTracklist: Bool {
        source != nil
            && (tracklistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasBlockingWarning)
    }

    var albumMetadata: AlbumMetadata {
        AlbumMetadata(
            album: albumTitle.trimmed,
            albumArtist: albumArtist.trimmed,
            year: Int(yearText.trimmed),
            genre: genre.trimmed.isEmpty ? nil : genre.trimmed,
            comment: comment.trimmed.isEmpty ? nil : comment.trimmed,
            artworkJPEG: artwork?.jpeg,
            compilation: isCompilation)
    }

    /// Default album folder name: `"Album Artist - Album"`.
    var folderName: String {
        let artist = albumArtist.trimmed, album = albumTitle.trimmed
        return artist.isEmpty ? album : "\(artist) - \(album)"
    }

    var canExport: Bool { source != nil && outputFolder != nil && albumMetadata.isComplete }

    var exportRequest: ExportRequest? {
        guard let source, let outputFolder else { return nil }
        return ExportRequest(
            source: source.url, sourceInfo: source.info, tracks: tracks,
            leadIn: parseOptions.leadInStrategy, album: albumMetadata,
            settings: ExportSettings(
                outputDirectory: outputFolder.url, folderName: folderName,
                existingFolderPolicy: existingFolderPolicy))
    }

    // MARK: Actions

    func go(to step: AppFlow.Step) {
        self.step = step
    }

    /// Runs the parser now (used after paste and by tests); the observers use
    /// the debounced `scheduleReparse()`.
    func reparse() {
        reparseTask?.cancel()
        parseResult = parser.parse(text: tracklistText, options: parseOptions)
    }

    /// Debounces per-keystroke parsing by ~100 ms (§10) so a fast typist doesn't
    /// churn the preview; the parser itself is fast enough that this is purely
    /// to avoid UI flicker.
    private func scheduleReparse() {
        reparseTask?.cancel()
        reparseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self else { return }
            self.parseResult = self.parser.parse(text: self.tracklistText, options: self.parseOptions)
        }
    }

    /// Clears everything tied to one source file so the next set starts fresh.
    func startOver() {
        reparseTask?.cancel()
        source = nil
        tracklistText = ""
        parseResult = ParseResult()
        edits = TrackEdits()
        albumTitle = ""
        albumArtist = ""
        comment = ""
        isCompilation = false
        artwork = nil
        existingFolderPolicy = .fail
        exportState = .idle
        step = .importFile
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
