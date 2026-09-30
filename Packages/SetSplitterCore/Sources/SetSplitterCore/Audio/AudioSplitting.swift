//
//  AudioSplitting.swift
//  SetSplitterCore
//

import AVFoundation

/// Cuts the source into files. Protocol so `ExportJob` can be tested with stubs.
public protocol AudioSplitting: Sendable {
    /// Writes one `.m4a` per planned track into `directory` (which must exist)
    /// and returns their URLs in track order. Throws `CancellationError` if
    /// the surrounding task is cancelled; partial files are removed.
    func split(
        source: URL,
        sourceInfo: AudioSourceInfo,
        plan: [PlannedTrack],
        directory: URL,
        settings: ExportSettings,
        metadata: AlbumMetadata,
        progress: @escaping @Sendable (ExportProgress) -> Void
    ) async throws -> [URL]
}
