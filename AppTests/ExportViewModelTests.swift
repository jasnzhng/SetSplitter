import Foundation
import Testing
@testable import SetSplitter
import SetSplitterCore

@MainActor
@Suite("ExportViewModel")
struct ExportViewModelTests {

    private func ready(splitter: StubSplitter) throws -> (ExportViewModel, SessionStore, URL) {
        let store = Fixtures.store()
        let parent = try Fixtures.tempDirectory()
        store.albumTitle = "Set"; store.albumArtist = "DJ"
        store.outputFolder = OutputFolder(url: parent, access: nil)
        store.tracklistText = "0:00 A - One\n1:00 B - Two"; store.reparse()
        let vm = ExportViewModel(store: store, picker: StubPicker(), preferences: StubPreferences(), job: ExportJob(splitter: splitter))
        return (vm, store, parent)
    }

    @Test("a successful export ends in .finished with the planned files")
    func succeeds() async throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter())
        defer { try? FileManager.default.removeItem(at: parent) }
        vm.export()
        #expect(await waitUntil { if case .finished = store.exportState { true } else { false } })
        guard case .finished(let result) = store.exportState else { return }
        #expect(result.files.count == 2)
        #expect(result.folder.lastPathComponent == "DJ - Set")
    }

    @Test("a failing export ends in .failed with the typed error's message")
    func fails() async throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter(failure: .diskFull))
        defer { try? FileManager.default.removeItem(at: parent) }
        vm.export()
        #expect(await waitUntil { if case .failed = store.exportState { true } else { false } })
        guard case .failed(let message) = store.exportState else { return }
        #expect(message == ExportError.diskFull.localizedDescription)
    }

    @Test("Cancel reaches the detached worker and returns to .idle")
    func cancels() async throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter(hang: true))
        defer { try? FileManager.default.removeItem(at: parent) }
        vm.export()
        #expect(await waitUntil { store.exportState.isRunning })
        vm.cancel()
        #expect(await waitUntil(timeout: .seconds(3)) { if case .idle = store.exportState { true } else { false } },
                "cancellation must propagate through Task.detached")
        // No partial output or hidden temp folder is left behind.
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
    }

    @Test("export does nothing until the form is complete, but reveals validation")
    func validation() throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter())
        defer { try? FileManager.default.removeItem(at: parent) }
        store.albumArtist = ""
        vm.export()
        #expect(vm.showsValidation)
        if case .idle = store.exportState {} else { Issue.record("should not have started") }
    }

    @Test("an existing folder asks instead of overwriting")
    func existingFolder() throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter())
        defer { try? FileManager.default.removeItem(at: parent) }
        try FileManager.default.createDirectory(at: parent.appendingPathComponent("DJ - Set"), withIntermediateDirectories: true)
        vm.export()
        #expect(vm.isAskingAboutExistingFolder)
        if case .idle = store.exportState {} else { Issue.record("should be waiting for the user's choice") }
    }

    @Test("artwork from a web URL is refused without touching the network")
    func rejectsRemoteArtwork() async throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter())
        defer { try? FileManager.default.removeItem(at: parent) }
        await vm.useImage(from: URL(string: "https://example.com/cover.jpg")!)
        #expect(store.artwork == nil)
        #expect(vm.artworkError != nil)
    }

    // MARK: Generated cover

    @Test("Generate is the default mode, and a refresh renders a cover from the album title")
    func generatesByDefault() async throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter())
        defer { try? FileManager.default.removeItem(at: parent) }
        #expect(store.artworkMode == .generate)
        #expect(store.artwork == nil)
        vm.refreshCover(debounced: false)
        #expect(await waitUntil { store.artwork != nil })
    }

    @Test("editing the title re-renders the cover; a burst of edits ends on the latest one")
    func liveUpdate() async throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter())
        defer { try? FileManager.default.removeItem(at: parent) }
        vm.refreshCover(debounced: false)
        #expect(await waitUntil { store.artwork != nil })
        let first = store.artwork?.jpeg

        for title in ["S", "Se", "Set Two"] { store.albumTitle = title; vm.refreshCover() }
        #expect(await waitUntil { store.artwork?.jpeg != first })
        try await Task.sleep(for: .milliseconds(600))   // let any stale render land; it must not overwrite the newest
        store.albumTitle = "Set Two"
        vm.refreshCover(debounced: false)
        #expect(await waitUntil { store.artwork != nil })
        let settled = store.artwork?.jpeg
        try await Task.sleep(for: .milliseconds(400))
        #expect(store.artwork?.jpeg == settled)
    }

    @Test("switching to Upload uses the uploaded image (none by default) and stops the generator")
    func uploadMode() async throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter())
        defer { try? FileManager.default.removeItem(at: parent) }
        vm.refreshCover(debounced: false)
        #expect(await waitUntil { store.artwork != nil })

        vm.setArtworkMode(.upload)
        #expect(store.artwork == nil, "Upload with no image means no artwork")
        vm.refreshCover()   // ignored outside Generate mode
        try await Task.sleep(for: .milliseconds(400))
        #expect(store.artwork == nil)

        vm.setArtworkMode(.generate)
        #expect(await waitUntil { store.artwork != nil })
    }

    @Test("Export waits for a cover render that is still in flight")
    func exportWaitsForCover() async throws {
        let (vm, store, parent) = try ready(splitter: StubSplitter())
        defer { try? FileManager.default.removeItem(at: parent) }
        vm.refreshCover()      // debounced: still pending when Export is pressed
        vm.export()
        #expect(await waitUntil { if case .finished = store.exportState { true } else { false } })
        #expect(store.artwork != nil, "the export ran with the freshly rendered cover")
    }
}
