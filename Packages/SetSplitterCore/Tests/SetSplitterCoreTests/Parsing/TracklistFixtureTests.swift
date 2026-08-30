//
//  TracklistFixtureTests.swift
//  SetSplitterCoreTests
//
//  implementation.md §9. One parameterized test walks
//  Tests/SetSplitterCoreTests/Fixtures/tracklists/ and checks every
//  `NN-description.txt` against its sibling `NN-description.expected.json`
//  (an array of `{start, artist, title}` — the joined display strings).
//
//  An optional `NN-description.options.json` supplies non-default
//  `ParseOptions` keys. An empty expected array means "no tracks" and the
//  parser must also report `.noTimestampsFound`.
//

import Foundation
import Testing
@testable import SetSplitterCore

@Suite("Tracklist fixtures (§9)")
struct TracklistFixtureTests {

    /// Guards against the loader silently degrading to zero cases (a missing
    /// fixtures directory would otherwise make the parameterized test vacuously
    /// pass). Bump this when adding a fixture.
    @Test("the §9 fixture corpus is present")
    func corpusIsLoaded() {
        #expect(TracklistFixture.all.count == 8, "expected 8 fixtures, loaded \(TracklistFixture.all.count)")
    }

    @Test("fixture round-trips", arguments: TracklistFixture.all)
    func fixtureParsesToExpectation(_ fixture: TracklistFixture) throws {
        let result = TracklistParser().parse(text: fixture.input, options: fixture.options)

        #expect(
            result.tracks.count == fixture.expected.count,
            "\(fixture.name): expected \(fixture.expected.count) tracks, got \(result.tracks.count)"
        )

        for (i, expected) in fixture.expected.enumerated() where i < result.tracks.count {
            let track = result.tracks[i]
            #expect(track.index == i + 1, "\(fixture.name) track \(i): index")
            #expect(
                track.start == expected.start,
                "\(fixture.name) track \(i): start \(track.start.seconds) != \(expected.start.seconds)"
            )
            #expect(
                track.artist == expected.artist,
                "\(fixture.name) track \(i): artist \"\(track.artist)\" != \"\(expected.artist)\""
            )
            #expect(
                track.title == expected.title,
                "\(fixture.name) track \(i): title \"\(track.title)\" != \"\(expected.title)\""
            )
        }

        if fixture.expected.isEmpty {
            #expect(result.warnings.contains(.noTimestampsFound), "\(fixture.name): expected .noTimestampsFound")
            #expect(result.allWarnings.contains { $0.isBlocking }, "\(fixture.name): expected a blocking warning")
        }
    }
}

// MARK: - Fixture model

struct TracklistFixture: CustomStringConvertible, Sendable {
    struct Row: Sendable {
        let start: Timestamp
        let artist: String
        let title: String
    }

    let name: String
    let input: String
    let expected: [Row]
    let options: ParseOptions

    var description: String { name }

    static let all: [TracklistFixture] = {
        (try? load()) ?? []
    }()

    private static func load() throws -> [TracklistFixture] {
        let dir = try fixturesDirectory()
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let inputs = entries
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try inputs.map { url in
            let stem = url.deletingPathExtension().lastPathComponent
            let text = try String(contentsOf: url, encoding: .utf8)

            let expectedURL = dir.appendingPathComponent("\(stem).expected.json")
            let expectedData = try Data(contentsOf: expectedURL)
            let rows = try JSONDecoder().decode([RawRow].self, from: expectedData)

            let optionsURL = dir.appendingPathComponent("\(stem).options.json")
            let options: ParseOptions
            if let optionsData = try? Data(contentsOf: optionsURL) {
                options = try JSONDecoder().decode(FixtureOptions.self, from: optionsData).applied(to: .default)
            } else {
                options = .default
            }

            return TracklistFixture(
                name: stem,
                input: text,
                expected: rows.map { row in
                    guard let ts = Timestamp(text: row.start) else {
                        fatalError("fixture \(stem): bad start \"\(row.start)\"")
                    }
                    return Row(start: ts, artist: row.artist, title: row.title)
                },
                options: options
            )
        }
    }

    private struct RawRow: Decodable {
        let start: String
        let artist: String
        let title: String
    }

    private static func fixturesDirectory(file: StaticString = #filePath) throws -> URL {
        var dir = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
        let fm = FileManager.default
        for _ in 0..<8 {
            if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
                    .appendingPathComponent("Tests")
                    .appendingPathComponent("SetSplitterCoreTests")
                    .appendingPathComponent("Fixtures")
                    .appendingPathComponent("tracklists")
            }
            dir.deleteLastPathComponent()
        }
        throw FixtureError.directoryNotFound
    }

    private enum FixtureError: Error { case directoryNotFound }
}

/// All-optional mirror of `ParseOptions` for partial fixture overrides.
private struct FixtureOptions: Decodable {
    var fieldOrder: String?
    var mashupStrategy: String?
    var leadInStrategy: String?
    var treatXAsArtistSeparator: Bool?
    var stripBracketedTags: Bool?
    var separatorMode: String?

    func applied(to base: ParseOptions) -> ParseOptions {
        var o = base
        if let v = fieldOrder, let parsed = ParseOptions.FieldOrder(rawValue: v) { o.fieldOrder = parsed }
        if let v = mashupStrategy, let parsed = ParseOptions.MashupStrategy(rawValue: v) { o.mashupStrategy = parsed }
        if let v = leadInStrategy, let parsed = ParseOptions.LeadInStrategy(rawValue: v) { o.leadInStrategy = parsed }
        if let v = treatXAsArtistSeparator { o.treatXAsArtistSeparator = v }
        if let v = stripBracketedTags { o.stripBracketedTags = v }
        if let v = separatorMode {
            switch v {
            case "auto":   o.separatorMode = .auto
            case "hyphen": o.separatorMode = .hyphen
            case "enDash": o.separatorMode = .enDash
            case "emDash": o.separatorMode = .emDash
            case "colon":  o.separatorMode = .colon
            case "slash":  o.separatorMode = .slash
            default:       o.separatorMode = .custom(v)
            }
        }
        return o
    }
}
