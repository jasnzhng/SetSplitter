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
    /// The same monospaced face `Theme.display` uses for headlines, so covers match the app.
    private let coverGenerator = CoverArtGenerator(titleFont: { size in
        NSFont.monospacedSystemFont(ofSize: size, weight: .heavy) as CTFont
    })
    private var exportTask: Task<Void, Never>?
    private var coverTask: Task<Void, Never>?
    private var coverGeneration = 0

    init(store: SessionStore, picker: any FilePicking, preferences: any PreferencesStoring, job: ExportJob) {
        self.store = store
        self.picker = picker
        self.preferences = preferences
        self.job = job
    }

    // MARK: Artwork

    /// Switches between the generator and the user's own image, making `store.artwork` match.
    func setArtworkMode(_ mode: ArtworkMode) {
        guard mode != store.artworkMode else { return }
        store.artworkMode = mode
        artworkError = nil
        switch mode {
        case .generate: refreshCover(debounced: false)
        case .upload:
            invalidateCoverRender()
            store.artwork = store.uploadedArtwork
        }
    }

    /// Chooses the file for whichever mode is active: the whole cover (Upload) or just the backdrop (Generate).
    func browseForArtwork() async {
        guard let url = await picker.chooseImage() else { return }
        await useImage(from: url)
    }

    /// Reads and prepares an image off the main actor (a large image decode would
    /// otherwise beachball the window). Only local files are accepted: a drag from a
    /// browser can carry an http URL, and `Data(contentsOf:)` would fetch it synchronously.
    func useImage(from url: URL) async {
        guard url.isFileURL else {
            artworkError = "Drop an image file from Finder, not a web link."
            return
        }
        let access = SecurityScopedAccess(url: url)
        defer { withExtendedLifetime(access) {} }
        switch store.artworkMode {
        case .upload:
            await install { try Data(contentsOf: url) }
        case .generate:
            let preparer = artworkPreparer
            let prepared = await Task.detached(priority: .userInitiated) { () -> Result<PreparedArtwork, Error> in
                Result { try preparer.prepare(Data(contentsOf: url)) }
            }.value
            switch prepared {
            case .success(let art):
                store.cover.background = art.jpeg
                store.cover.backgroundName = url.lastPathComponent
                artworkError = nil
                refreshCover(debounced: false)
            case .failure(let error):
                artworkError = (error as? LocalizedError)?.errorDescription ?? "That image couldn't be read."
            }
        }
    }

    func removeArtwork() {
        store.uploadedArtwork = nil
        store.artwork = nil
        artworkError = nil
    }

    // MARK: Generated cover

    func removeBackground() {
        store.cover.background = nil
        store.cover.backgroundName = nil
        store.cover.filter = .none
        refreshCover(debounced: false)
    }

    func shuffleColors() {
        let count = CoverScheme.all.count
        store.cover.schemeIndex = (store.cover.schemeIndex + Int.random(in: 1..<count)) % count
        refreshCover(debounced: false)
    }

    /// Re-renders the generated cover from the album title and design. Typing debounces so a burst of
    /// keystrokes renders once; the latest request always wins. No-op outside Generate mode.
    func refreshCover(debounced: Bool = true) {
        guard store.artworkMode == .generate else { return }
        coverGeneration += 1
        let generation = coverGeneration
        coverTask?.cancel()
        let title = store.albumTitle, style = store.cover.style
        let preparer = artworkPreparer, generator = coverGenerator
        coverTask = Task {
            if debounced {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
            }
            let result = await Task.detached(priority: .userInitiated) { () -> Result<(PreparedArtwork, [SRGBColor]), Error> in
                Result {
                    let prepared = try preparer.prepare(generator.generate(title: title, style: style))
                    return (prepared, CoverPalette().extract(from: prepared.jpeg))
                }
            }.value
            // A newer request (or a switch to Upload) owns the result now.
            guard generation == coverGeneration, store.artworkMode == .generate else { return }
            coverTask = nil
            switch result {
            case .success(let (prepared, palette)):
                store.artwork = Artwork(prepared: prepared, palette: palette)
                artworkError = nil
            case .failure(let error):
                artworkError = (error as? LocalizedError)?.errorDescription ?? "The cover couldn't be generated."
            }
        }
    }

    private func invalidateCoverRender() {
        coverGeneration += 1
        coverTask?.cancel()
        coverTask = nil
    }

    /// Runs `produce` → `ArtworkPreparer` → `CoverPalette` off the main actor and publishes the upload.
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
            let art = Artwork(prepared: prepared, palette: palette)
            store.uploadedArtwork = art
            store.artwork = art
            artworkError = nil
        case .failure(let error):
            artworkError = (error as? LocalizedError)?.errorDescription ?? "That image couldn't be read."
        }
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
        // A cover render still in flight (the user typed, then hit Export) must land first, or the
        // files would be tagged with the previous title's art.
        if let pending = coverTask {
            Task { await pending.value; export() }
            return
        }
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
