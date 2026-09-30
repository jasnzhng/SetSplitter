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
        await vm.loadArtwork(from: URL(string: "https://example.com/cover.jpg")!)
        #expect(store.artwork == nil)
        #expect(vm.artworkError != nil)
    }
}
