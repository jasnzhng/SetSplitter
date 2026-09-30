//
//  TestDoubles.swift
//  SetSplitterTests
//
//  Stubs for the app's service protocols, so view models and the store can be
//  tested without panels, UserDefaults, or real audio.
//

import Foundation
@testable import SetSplitter
import SetSplitterCore

@MainActor
final class StubPreferences: PreferencesStoring {
    var options = ParseOptions.default
    var genre: String?
    var savedOptionsCount = 0
    func loadParseOptions() -> ParseOptions { options }
    func saveParseOptions(_ options: ParseOptions) { self.options = options; savedOptionsCount += 1 }
    func loadGenre() -> String? { genre }
    func saveGenre(_ genre: String) { self.genre = genre }
    func loadOutputFolder() -> SecurityScopedAccess? { nil }
    func saveOutputFolder(_ url: URL) {}
}

@MainActor
final class StubPicker: FilePicking {
    var audio: URL?
    var image: URL?
    var folder: URL?
    func chooseAudioFile() async -> URL? { audio }
    func chooseImage() async -> URL? { image }
    func chooseFolder(startingAt: URL?) async -> URL? { folder }
}

/// Inspector that returns a fixed result, optionally after a delay (per URL) to force out-of-order completion.
struct StubInspector: AudioInspecting {
    var info = AudioSourceInfo(duration: 600, sampleRate: 44_100, channels: 2, codecName: "MP3")
    var delays: [String: Duration] = [:]
    var failure: InspectionError?

    func inspect(url: URL) async throws -> AudioSourceInfo {
        if let delay = delays[url.lastPathComponent] { try await Task.sleep(for: delay) }
        if let failure { throw failure }
        return info
    }
}

/// Splitter that writes nothing. `hang` makes it wait until cancelled; `failure` makes it throw.
struct StubSplitter: AudioSplitting {
    var hang = false
    var failure: ExportError?

    func split(
        source: URL, sourceInfo: AudioSourceInfo, plan: [PlannedTrack], directory: URL,
        settings: ExportSettings, metadata: AlbumMetadata, progress: @escaping @Sendable (ExportProgress) -> Void
    ) async throws -> [URL] {
        if hang { try await Task.sleep(for: .seconds(60)) }
        if let failure { throw failure }
        return plan.map { directory.appendingPathComponent($0.filename) }
    }
}

enum Fixtures {
    static let mp3 = URL(fileURLWithPath: "/tmp/set.mp3")

    @MainActor
    static func store(prefs: StubPreferences = StubPreferences(), withSource: Bool = true) -> SessionStore {
        let store = SessionStore(preferences: prefs)
        if withSource {
            store.source = SourceFile(
                url: mp3, info: AudioSourceInfo(duration: 600, sampleRate: 44_100, channels: 2, codecName: "MP3"),
                access: SecurityScopedAccess(url: mp3))
        }
        return store
    }

    static func tempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SetSplitterAppTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

/// Polls until `condition` holds (or fails after `timeout`), yielding to the main actor between checks.
@MainActor
func waitUntil(timeout: Duration = .seconds(5), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
