//
//  ExportJob.swift
//  SetSplitterCore
//
//  implementation.md §7.9. Orchestrates plan → temp folder → split + tag →
//  cover.jpg → atomic move into the final folder. Talks to the audio layer
//  only through `AudioSplitting`.
//

import Foundation

public struct ExportJob: Sendable {

    private let splitter: any AudioSplitting
    private let planner: ExportPlanner
    private let discardReplaced: @Sendable (URL) -> Void

    /// - Parameter discardReplaced: Disposes of an album that `.replace` displaced.
    ///   Defaults to moving it to the Trash; tests inject a plain delete so they don't
    ///   litter the developer's Trash.
    public init(
        splitter: any AudioSplitting = AVFoundationAudioSplitter(),
        planner: ExportPlanner = ExportPlanner(),
        discardReplaced: @escaping @Sendable (URL) -> Void = { try? FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) {
        self.splitter = splitter
        self.planner = planner
        self.discardReplaced = discardReplaced
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

        Self.sweepAbandonedTempFolders(in: settings.outputDirectory)

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
            do { try jpeg.write(to: url) } catch {
                throw ExportError.cannotCreateFolder("The cover image couldn't be saved. \(error.localizedDescription)")
            }
            cover = url
        }

        try Task.checkCancellation()
        progress(ExportProgress(
            phase: .finalizing, framesProcessed: request.sourceInfo.totalFrames,
            totalFrames: request.sourceInfo.totalFrames, currentTrack: plan.tracks.count,
            trackCount: plan.tracks.count, currentTitle: ""))

        // `.replace`: move the old album aside first and trash it only once the new one is in
        // place, so a failed move can put it back instead of losing both.
        var displaced: URL?
        if fm.fileExists(atPath: final.path) {
            // A *visible* name: it ends up in the Trash, where a dot-name would be hidden, and it
            // must never match the `.SetSplitter-` prefix the abandoned-temp sweep deletes.
            let aside = Self.freeName("\(final.lastPathComponent) (replaced)", in: settings.outputDirectory)
            do { try fm.moveItem(at: final, to: aside) } catch {
                throw ExportError.cannotCreateFolder("The existing folder couldn't be replaced. \(error.localizedDescription)")
            }
            displaced = aside
        }
        do { try fm.moveItem(at: temp, to: final) } catch {
            if let displaced { try? fm.moveItem(at: displaced, to: final) }   // restore the old album
            throw ExportError.cannotCreateFolder(error.localizedDescription)
        }
        succeeded = true
        if let displaced { discardReplaced(displaced) }

        let moved = { (u: URL) in final.appendingPathComponent(u.lastPathComponent) }
        progress(ExportProgress(
            phase: .done, framesProcessed: request.sourceInfo.totalFrames,
            totalFrames: request.sourceInfo.totalFrames, currentTrack: plan.tracks.count,
            trackCount: plan.tracks.count, currentTitle: ""))
        return ExportResult(folder: final, files: files.map(moved), coverURL: cover.map(moved), warnings: plan.warnings)
    }

    /// `name`, or `name 2`, `name 3`, … — the first folder name not already present in `directory`.
    private static func freeName(_ name: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(name, isDirectory: true)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(name) \(n)", isDirectory: true)
            n += 1
        }
        return candidate
    }

    /// A crash or force-quit mid-export leaves a hidden `.SetSplitter-<uuid>` folder full of
    /// partial audio behind. Remove any that are over a day old (never one that may belong
    /// to an export running right now).
    private static func sweepAbandonedTempFolders(in directory: URL) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else { return }
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        for url in entries where url.lastPathComponent.hasPrefix(".SetSplitter-") {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? fm.removeItem(at: url) }
        }
    }
}
