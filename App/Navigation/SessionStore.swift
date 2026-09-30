//
//  SessionStore.swift
//  SetSplitter
//
//  implementation.md §10. The single source of truth across the three screens.
//  View models read and write it; it owns no AVFoundation and no UI.
//

import Foundation
import Observation
import SwiftUI
import SetSplitterCore

@MainActor
@Observable
final class SessionStore {

    // MARK: Flow

    var step: AppFlow.Step = .importFile

    // MARK: Import

    var source: SourceFile? {
        didSet { refreshDerived() }
    }

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

    private(set) var parseResult = ParseResult() {
        didSet { refreshDerived() }
    }

    /// Manual corrections, layered over each re-parse (keyed by timestamp).
    var edits = TrackEdits() {
        didSet { refreshDerived() }
    }

    // Derived from `parseResult`, `edits` and `source`. Cached because several
    // views read them on every body pass and `edits.applying` allocates.

    /// Parser output with the user's inline edits applied.
    private(set) var tracks: [ParsedTrack] = []

    /// Seconds per track, aligned with `tracks`.
    private(set) var durations: [Double] = []

    /// Every warning worth showing under the preview, document-level first.
    private(set) var warnings: [ParseWarning] = []

    // MARK: Album

    var albumTitle = ""

    /// The last title we filled in from a filename. Lets a new file re-guess
    /// the title unless the user has typed their own.
    private(set) var guessedAlbumTitle: String?
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

    private func refreshDerived() {
        tracks = edits.applying(to: parseResult.tracks)
        durations = TrackTiming.durations(of: tracks, sourceDuration: source?.info.duration ?? 0)
        warnings = parseResult.warnings + tracks.flatMap(\.warnings)
    }

    var hasBlockingWarning: Bool { warnings.contains(where: \.isBlocking) }

    /// An empty tracklist parses to no warnings at all (see `parse()`), so only
    /// pasted-but-unparseable text blocks.
    var canLeaveTracklist: Bool { source != nil && !hasBlockingWarning }

    /// The release year, when `yearText` is a plausible four-digit year.
    var year: Int? {
        guard let value = Int(yearText.trimmed), (1000...9999).contains(value) else { return nil }
        return value
    }

    /// Empty is allowed (the tag is simply omitted); anything else must be a real year.
    var yearIsValid: Bool { yearText.trimmed.isEmpty || year != nil }

    var albumMetadata: AlbumMetadata {
        AlbumMetadata(
            album: albumTitle.trimmed,
            albumArtist: albumArtist.trimmed,
            year: year,
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

    var canExport: Bool { source != nil && outputFolder != nil && albumMetadata.isComplete && yearIsValid }

    /// What an export would actually write: ordering, dropped tracks and the
    /// single-track fallback all applied. The form's track count comes from here
    /// so it always matches the files.
    var exportPlan: ExportPlan? {
        guard let source else { return nil }
        return ExportPlanner().plan(
            tracks: tracks, source: source.info, leadIn: parseOptions.leadInStrategy,
            albumTitle: albumTitle.trimmed)
    }

    var exportRequest: ExportRequest? {
        guard let source, let outputFolder else { return nil }
        return ExportRequest(
            source: source.url, sourceInfo: source.info, tracks: tracks,
            leadIn: parseOptions.leadInStrategy, album: albumMetadata,
            settings: ExportSettings(
                outputDirectory: outputFolder.url, folderName: folderName,
                existingFolderPolicy: existingFolderPolicy))
    }

    /// The palette behind the window. Once cover art is chosen, the Export step (and the
    /// finished screen) take their colours from it; other steps keep their resting palette.
    var backdropPalette: ArtPalette {
        if step == .export, let fromCover = artwork.flatMap({ ArtPalette.from($0.palette) }) { return fromCover }
        return .resting(for: step)
    }

    // MARK: Actions

    func go(to step: AppFlow.Step) {
        self.step = step
    }

    /// Runs the parser now (used after paste and by tests); the observers use
    /// the debounced `scheduleReparse()`.
    func reparse() {
        reparseTask?.cancel()
        withAnimation(Theme.smooth) { parseResult = parse() }
    }

    /// An empty tracklist is legal (§14: one track named after the album), so it
    /// shows no tracks *and* no warnings rather than the parser's "no timestamps".
    private func parse() -> ParseResult {
        tracklistText.trimmed.isEmpty ? ParseResult() : parser.parse(text: tracklistText, options: parseOptions)
    }

    /// Fills the album title from `filename` unless the user has typed their own.
    func guessAlbumTitle(fromFilename filename: String) {
        guard albumTitle.trimmed.isEmpty || albumTitle == guessedAlbumTitle else { return }
        let guess = AlbumNameGuesser.guess(fromFilename: filename)
        albumTitle = guess
        guessedAlbumTitle = guess
    }

    /// Debounces per-keystroke parsing by ~100 ms (§10) so a fast typist doesn't
    /// churn the preview; the parser itself is fast enough that this is purely
    /// to avoid UI flicker.
    private func scheduleReparse() {
        reparseTask?.cancel()
        reparseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self else { return }
            withAnimation(Theme.smooth) { self.parseResult = self.parse() }
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
        guessedAlbumTitle = nil
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
