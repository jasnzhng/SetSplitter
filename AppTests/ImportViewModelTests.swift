import Foundation
import Testing
@testable import SetSplitter
import SetSplitterCore

@MainActor
@Suite("ImportViewModel")
struct ImportViewModelTests {

    private func model(store: SessionStore, inspector: StubInspector = StubInspector(), picker: StubPicker = StubPicker()) -> ImportViewModel {
        ImportViewModel(store: store, inspector: inspector, picker: picker)
    }

    @Test("loading an mp3 publishes the source and guesses the album")
    func loads() async {
        let store = Fixtures.store(withSource: false)
        let vm = model(store: store)
        await vm.load(URL(fileURLWithPath: "/tmp/Cool_Set.mp3"))
        #expect(store.source?.filename == "Cool_Set.mp3")
        #expect(store.albumTitle == "Cool Set")
        #expect(vm.phase == .idle)
    }

    @Test("non-mp3 files are rejected with a message")
    func rejectsWrongType() async {
        let store = Fixtures.store(withSource: false)
        let vm = model(store: store)
        await vm.load(URL(fileURLWithPath: "/tmp/song.wav"))
        #expect(store.source == nil)
        guard case .failed(let message) = vm.phase else { Issue.record("expected failure"); return }
        #expect(message.contains("song.wav"))
    }

    @Test("dropping several files is rejected")
    func rejectsMultipleDrop() async {
        let store = Fixtures.store(withSource: false)
        let vm = model(store: store)
        let accepted = await vm.handleDrop([URL(fileURLWithPath: "/tmp/a.mp3"), URL(fileURLWithPath: "/tmp/b.mp3")])
        #expect(!accepted)
        #expect(store.source == nil)
    }

    @Test("an inspection failure surfaces its message and leaves no source")
    func inspectionFailure() async {
        let store = Fixtures.store(withSource: false)
        let vm = model(store: store, inspector: StubInspector(failure: .noAudioTrack))
        await vm.load(URL(fileURLWithPath: "/tmp/bad.mp3"))
        #expect(store.source == nil)
        #expect(vm.phase == .failed(InspectionError.noAudioTrack.localizedDescription))
    }

    @Test("two quick loads: the later one wins even if the earlier finishes last")
    func latestLoadWins() async {
        let store = Fixtures.store(withSource: false)
        let inspector = StubInspector(delays: ["slow.mp3": .milliseconds(200)])
        let vm = model(store: store, inspector: inspector)
        async let first: Void = vm.load(URL(fileURLWithPath: "/tmp/slow.mp3"))
        try? await Task.sleep(for: .milliseconds(20))
        await vm.load(URL(fileURLWithPath: "/tmp/fast.mp3"))
        await first
        #expect(store.source?.filename == "fast.mp3")
    }

    @Test("loading a different file discards edits from the previous tracklist")
    func newFileResetsEdits() async {
        let store = Fixtures.store()
        store.edits.setTitle("Old", at: Timestamp(seconds: 0))
        let vm = model(store: store)
        await vm.load(URL(fileURLWithPath: "/tmp/another.mp3"))
        #expect(store.edits.isEmpty)
    }

    @Test("Continue does nothing without a source")
    func advanceNeedsSource() {
        let store = Fixtures.store(withSource: false)
        model(store: store).advance()
        #expect(store.step == .importFile)
    }
}
