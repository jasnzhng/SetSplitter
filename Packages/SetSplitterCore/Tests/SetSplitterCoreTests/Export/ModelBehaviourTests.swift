import AVFoundation
import Foundation
import Testing
@testable import SetSplitterCore

@Suite("Model behaviour")
struct ModelBehaviourTests {

    // MARK: ExportProgress

    @Test("fraction is clamped, zero without a total, and 1 when done")
    func fraction() {
        #expect(ExportProgress(framesProcessed: 50, totalFrames: 100).fraction == 0.5)
        #expect(ExportProgress(framesProcessed: 500, totalFrames: 100).fraction == 1)
        #expect(ExportProgress(framesProcessed: -5, totalFrames: 100).fraction == 0)
        #expect(ExportProgress(framesProcessed: 5, totalFrames: 0).fraction == 0)
        #expect(ExportProgress(phase: .done, framesProcessed: 0, totalFrames: 100).fraction == 1)
    }

    // MARK: AudioSourceInfo

    @Test("total frames rounds duration × rate; summary formats rate and layout")
    func sourceInfo() {
        #expect(AudioSourceInfo(duration: 1.00002, sampleRate: 44_100, channels: 2).totalFrames == 44_101)
        #expect(AudioSourceInfo(duration: 10, sampleRate: 44_100, channels: 2, codecName: "MP3").summary == "MP3 · 44.1 kHz · Stereo")
        #expect(AudioSourceInfo(duration: 10, sampleRate: 48_000, channels: 1, codecName: "AAC").summary == "AAC · 48 kHz · Mono")
    }

    // MARK: ParseOptions (persisted as JSON)

    @Test("options round-trip through JSON, including the custom separator")
    func optionsCodable() throws {
        var options = ParseOptions.default
        options.separatorMode = .custom(" ~ ")
        options.fieldOrder = .titleThenArtist
        options.leadInStrategy = .trim
        options.treatXAsArtistSeparator = true
        let data = try JSONEncoder().encode(options)
        #expect(try JSONDecoder().decode(ParseOptions.self, from: data) == options)
    }

    // MARK: ExportJob.destination

    @Test("destination sanitises the folder name and picks a free name for keepBoth")
    func destination() throws {
        let parent = try AudioTestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        var settings = ExportSettings(outputDirectory: parent, folderName: "AC/DC: Live")
        #expect(ExportJob.destination(for: settings).lastPathComponent == "AC-DC- Live")

        try FileManager.default.createDirectory(at: parent.appendingPathComponent("AC-DC- Live"), withIntermediateDirectories: true)
        settings.existingFolderPolicy = .keepBoth
        #expect(ExportJob.destination(for: settings).lastPathComponent == "AC-DC- Live (2)")
        settings.existingFolderPolicy = .replace
        #expect(ExportJob.destination(for: settings).lastPathComponent == "AC-DC- Live")
    }

    // MARK: Timestamp

    @Test("absurd or non-finite values don't trap")
    func timestampGuards() {
        #expect(Timestamp(text: "99999999999999999999:00:00") == nil)
        #expect(Timestamp(text: "100000:00") == nil)
        #expect(Timestamp(seconds: .infinity).displayString == "0:00")
        #expect(Timestamp(seconds: .nan).displayString == "0:00")
    }

    // MARK: Planner

    @Test("two tracks landing on the same sample warn and keep the first")
    func plannerDuplicateWarning() {
        let source = AudioSourceInfo(duration: 100, sampleRate: 1000, channels: 2)
        func track(_ s: Double, _ t: String) -> ParsedTrack {
            ParsedTrack(index: 1, start: Timestamp(seconds: s), artists: [], titles: [t], rawText: "")
        }
        let plan = ExportPlanner().plan(tracks: [track(0, "a"), track(30, "b"), track(30.0004, "c")],
                                        source: source, leadIn: .includeInFirstTrack, albumTitle: "x")
        #expect(plan.tracks.map(\.displayTitle) == ["a", "b"])
        #expect(plan.warnings == [.duplicateTimestamp(Timestamp(seconds: 30.0004))])
    }
}

@Suite("MetadataBuilder")
struct MetadataBuilderTests {

    private func planned(artist: [String], number: Int = 2) -> PlannedTrack {
        PlannedTrack(
            track: ParsedTrack(index: number, start: Timestamp(seconds: 0), artists: artist, titles: ["T"], rawText: ""),
            range: 0..<100, trackNumber: number, filename: "x.m4a")
    }

    private func value(_ id: AVMetadataIdentifier, in items: [AVMetadataItem]) -> AVMetadataItem? {
        items.first { $0.identifier == id }
    }

    @Test("track/disc numbers are the 8-byte big-endian blob")
    func numberPair() {
        #expect(MetadataBuilder.numberPair(2, of: 14) == Data([0, 0, 0, 2, 0, 14, 0, 0]))
        #expect(MetadataBuilder.numberPair(300, of: 300) == Data([0, 0, 1, 44, 1, 44, 0, 0]))
    }

    @Test("empty track artist falls back to the album artist")
    func artistFallback() {
        let album = AlbumMetadata(album: "A", albumArtist: "DJ Album")
        let items = MetadataBuilder.items(for: planned(artist: []), album: album, totalTracks: 3)
        #expect(value(.iTunesMetadataArtist, in: items)?.stringValue == "DJ Album")
        let withArtist = MetadataBuilder.items(for: planned(artist: ["Solo"]), album: album, totalTracks: 3)
        #expect(value(.iTunesMetadataArtist, in: withArtist)?.stringValue == "Solo")
    }

    @Test("optional fields are omitted when unset; pgap follows the gapless flag")
    func optionalFields() {
        var album = AlbumMetadata(album: "A", albumArtist: "B", gaplessAlbum: false)
        let bare = MetadataBuilder.items(for: planned(artist: ["x"]), album: album, totalTracks: 1)
        #expect(value(.iTunesMetadataReleaseDate, in: bare) == nil)
        #expect(value(.iTunesMetadataUserGenre, in: bare) == nil)
        #expect(value(.iTunesMetadataCoverArt, in: bare) == nil)
        #expect(!bare.contains { ($0.key as? String) == "pgap" })

        album.gaplessAlbum = true
        album.year = 2026
        let full = MetadataBuilder.items(for: planned(artist: ["x"]), album: album, totalTracks: 1)
        #expect(full.contains { ($0.key as? String) == "pgap" })
        #expect(value(.iTunesMetadataReleaseDate, in: full)?.stringValue == "2026")
    }
}
