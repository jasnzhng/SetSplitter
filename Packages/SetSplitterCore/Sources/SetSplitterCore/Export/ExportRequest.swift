//
//  ExportRequest.swift
//  SetSplitterCore
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
