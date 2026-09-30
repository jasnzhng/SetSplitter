//
//  ExportJob.swift
//  SetSplitterCore
//
//  implementation.md §7.9. Orchestrates plan → temp folder → split + tag →
//  cover.jpg → atomic move into the final folder. Talks to the audio layer
//  only through `AudioSplitting`.
//

import Foundation

/// Everything one export needs.
public struct ExportRequest: Sendable {
    public var source: URL
    public var sourceInfo: AudioSourceInfo
    public var tracks: [ParsedTrack]
    public var leadIn: ParseOptions.LeadInStrategy
    public var album: AlbumMetadata
    public var settings: ExportSettings

    public init(
        source: URL, sourceInfo: AudioSourceInfo, tracks: [ParsedTrack],
        leadIn: ParseOptions.LeadInStrategy, album: AlbumMetadata, settings: ExportSettings
    ) {
        self.source = source
        self.sourceInfo = sourceInfo
        self.tracks = tracks
        self.leadIn = leadIn
        self.album = album
        self.settings = settings
    }
}

/// A finished export.
public struct ExportResult: Sendable {
    public var folder: URL
    public var files: [URL]
    public var coverURL: URL?
    public var warnings: [ParseWarning]

    public init(folder: URL, files: [URL], coverURL: URL?, warnings: [ParseWarning] = []) {
        self.folder = folder
        self.files = files
        self.coverURL = coverURL
        self.warnings = warnings
    }
}

public struct ExportJob: Sendable {

    private let splitter: any AudioSplitting
    private let planner: ExportPlanner

    public init(splitter: any AudioSplitting = AVFoundationAudioSplitter(), planner: ExportPlanner = ExportPlanner()) {
        self.splitter = splitter
        self.planner = planner
    }

    /// The folder `request` will be written to, after applying the
    /// existing-folder policy's naming (`keepBoth` picks a free name).
    public static func destination(for settings: ExportSettings) -> URL {
        let name = FilenameSanitizer.sanitize(settings.folderName)
        let base = settings.outputDirectory.appendingPathComponent(name.isEmpty ? "Export" : name, isDirectory: true)
        guard settings.existingFolderPolicy == .keepBoth else { return base }
        var candidate = base
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = settings.outputDirectory.appendingPathComponent("\(base.lastPathComponent) (\(n))", isDirectory: true)
            n += 1
        }
        return candidate
    }

    public func run(
        _ request: ExportRequest,
        progress: @escaping @Sendable (ExportProgress) -> Void = { _ in }
    ) async throws -> ExportResult {
        let fm = FileManager.default
        let settings = request.settings
        let plan = planner.plan(
            tracks: request.tracks, source: request.sourceInfo, leadIn: request.leadIn,
            albumTitle: request.album.album, template: settings.filenameTemplate)

        let final = Self.destination(for: settings)
        if fm.fileExists(atPath: final.path), settings.existingFolderPolicy == .fail {
            throw ExportError.destinationExists(final)
        }

        // Hidden sibling inside the chosen parent: same volume (so the final move is a
        // rename, not a copy) and inside the sandbox grant.
        let temp = settings.outputDirectory.appendingPathComponent(".SetSplitter-\(UUID().uuidString)", isDirectory: true)
        do {
            try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        } catch {
            throw ExportError.cannotCreateFolder(error.localizedDescription)
        }
        var succeeded = false
        defer { if !succeeded { try? fm.removeItem(at: temp) } }

        let files = try await splitter.split(
            source: request.source, sourceInfo: request.sourceInfo, plan: plan.tracks,
            directory: temp, settings: settings, metadata: request.album, progress: progress)

        var cover: URL?
        if let jpeg = request.album.artworkJPEG {
            let url = temp.appendingPathComponent("cover.jpg")
            try jpeg.write(to: url)
            cover = url
        }

        try Task.checkCancellation()
        progress(ExportProgress(
            phase: .finalizing, framesProcessed: request.sourceInfo.totalFrames,
            totalFrames: request.sourceInfo.totalFrames, currentTrack: plan.tracks.count,
            trackCount: plan.tracks.count, currentTitle: ""))

        if fm.fileExists(atPath: final.path) {   // only reachable with `.replace`
            do { try fm.trashItem(at: final, resultingItemURL: nil) } catch {
                throw ExportError.cannotCreateFolder("The existing folder couldn't be moved to the Trash. \(error.localizedDescription)")
            }
        }
        do { try fm.moveItem(at: temp, to: final) } catch {
            throw ExportError.cannotCreateFolder(error.localizedDescription)
        }
        succeeded = true

        let moved = { (u: URL) in final.appendingPathComponent(u.lastPathComponent) }
        progress(ExportProgress(
            phase: .done, framesProcessed: request.sourceInfo.totalFrames,
            totalFrames: request.sourceInfo.totalFrames, currentTrack: plan.tracks.count,
            trackCount: plan.tracks.count, currentTitle: ""))
        return ExportResult(folder: final, files: files.map(moved), coverURL: cover.map(moved), warnings: plan.warnings)
    }
}
