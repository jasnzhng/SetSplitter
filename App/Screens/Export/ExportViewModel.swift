//
//  ExportViewModel.swift
//  SetSplitter
//
//  Artwork, output folder and the export run itself. Calls Core only through
//  `ExportJob` (which takes an `AudioSplitting`), never AVFoundation.
//

import AppKit
import Observation
import SetSplitterCore

@MainActor
@Observable
final class ExportViewModel {

    let store: SessionStore

    /// Set when the chosen folder name already exists, to drive the
    /// Replace / Keep Both / Cancel dialog.
    var isAskingAboutExistingFolder = false

    /// Becomes `true` after the first Export attempt so required-field errors
    /// appear only once the user has tried to proceed.
    private(set) var showsValidation = false

    private(set) var artworkError: String?

    #if DEBUG
    /// Snapshot harness hook: show required-field errors without an export attempt.
    func markValidationShown() { showsValidation = true }
    #endif

    private let picker: any FilePicking
    private let preferences: any PreferencesStoring
    private let job: ExportJob
    private let artworkPreparer = ArtworkPreparer()
    private var exportTask: Task<Void, Never>?

    init(store: SessionStore, picker: any FilePicking, preferences: any PreferencesStoring, job: ExportJob) {
        self.store = store
        self.picker = picker
        self.preferences = preferences
        self.job = job
    }

    // MARK: Artwork

    func browseForArtwork() async {
        guard let url = await picker.chooseImage() else { return }
        await loadArtwork(from: url)
    }

    /// Reads and prepares artwork off the main actor (a large image decode would
    /// otherwise beachball the window). Only local files are accepted: a drag from a
    /// browser can carry an http URL, and `Data(contentsOf:)` would fetch it synchronously.
    func loadArtwork(from url: URL) async {
        guard url.isFileURL else {
            artworkError = "Drop an image file from Finder, not a web link."
            return
        }
        let access = SecurityScopedAccess(url: url)
        await install { try Data(contentsOf: url) }
        withExtendedLifetime(access) {}
    }

    /// Makes a cover from the set itself (title, artist and the tracklist's shape). Deterministic:
    /// the same set always produces the same cover.
    func generateCover() async {
        let title = store.albumTitle, artist = store.albumArtist, durations = store.durations
        await install { try CoverArtGenerator().generate(title: title, artist: artist, trackDurations: durations) }
    }

    /// Runs `produce` → `ArtworkPreparer` → `CoverPalette` off the main actor and publishes the result.
    private func install(_ produce: @escaping @Sendable () throws -> Data) async {
        let preparer = artworkPreparer
        let result = await Task.detached(priority: .userInitiated) { () -> Result<(PreparedArtwork, [SRGBColor]), Error> in
            Result {
                let prepared = try preparer.prepare(produce())
                return (prepared, CoverPalette().extract(from: prepared.jpeg))
            }
        }.value
        switch result {
        case .success(let (prepared, palette)):
            store.artwork = Artwork(prepared: prepared, palette: palette)
            artworkError = nil
        case .failure(let error):
            artworkError = (error as? LocalizedError)?.errorDescription ?? "That image couldn't be read."
        }
    }

    func removeArtwork() {
        store.artwork = nil
        artworkError = nil
    }

    // MARK: Folder

    func chooseFolder() async {
        guard let url = await picker.chooseFolder(startingAt: store.outputFolder?.url) else { return }
        store.outputFolder = OutputFolder(url: url, access: SecurityScopedAccess(url: url))
        preferences.saveOutputFolder(url)
    }

    // MARK: Export

    func back() { store.go(to: .tracklist) }

    /// Primary action. Validates, then either asks about an existing folder or starts.
    func export() {
        showsValidation = true
        guard store.canExport, !store.exportState.isRunning else { return }
        store.existingFolderPolicy = .fail
        if let request = store.exportRequest,
           FileManager.default.fileExists(atPath: ExportJob.destination(for: request.settings).path) {
            isAskingAboutExistingFolder = true
            return
        }
        start()
    }

    func resolveExistingFolder(_ policy: ExportSettings.ExistingFolderPolicy) {
        store.existingFolderPolicy = policy
        start()
    }

    func cancel() {
        exportTask?.cancel()
    }

    /// Cancels and waits for the job to clean up; used when quitting mid-export.
    func cancelAndWait() async {
        exportTask?.cancel()
        await exportTask?.value
    }

    func revealInFinder() {
        guard case .finished(let result) = store.exportState else { return }
        NSWorkspace.shared.activateFileViewerSelecting([result.folder])
    }

    /// From the Done / Failed screens back to an editable form.
    func editSettings() {
        store.exportState = .idle
    }

    func startOver() {
        store.startOver()
    }

    private func start() {
        guard let request = store.exportRequest else { return }
        store.exportState = .running(ExportProgress(
            totalFrames: request.sourceInfo.totalFrames, trackCount: max(1, request.tracks.count)))
        let job = self.job
        let store = self.store

        // Detached so the synchronous decode loop can never run on the main actor,
        // whatever the toolchain's default isolation for async functions is.
        // A detached task is *not* a child of `exportTask`, so cancellation must be
        // forwarded by hand or Cancel would silently do nothing.
        exportTask = Task {
            let worker = Task.detached(priority: .userInitiated) { () -> Result<ExportResult, Error> in
                do {
                    let result = try await job.run(request) { progress in
                        Task { @MainActor in
                            // Late callbacks must not overwrite a finished/failed state.
                            if case .running = store.exportState { store.exportState = .running(progress) }
                        }
                    }
                    return .success(result)
                } catch {
                    return .failure(error)
                }
            }
            let outcome = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            switch outcome {
            case .success(let result):
                store.exportState = .finished(result)
            case .failure(let error) where error is CancellationError:
                store.exportState = .idle
            case .failure(let error):
                store.exportState = .failed(error.localizedDescription)
            }
        }
    }
}
