//
//  AlbumMetadata.swift
//  SetSplitterCore
//
//  Album-level tags shared by every output track.
//

import Foundation

/// Album-level metadata stamped on every track of an export.
///
/// `albumArtist` is what makes Music group the tracks into one album, so the
/// Export screen treats it (and `album`) as required.
public struct AlbumMetadata: Hashable, Sendable {

    /// Album title. Required.
    public var album: String

    /// Album artist. Required — this is the tag Music groups by.
    public var albumArtist: String

    /// Release year, written as a four-character string.
    public var year: Int?

    public var genre: String?

    public var comment: String?

    /// Already-prepared JPEG bytes (see `ArtworkPreparer`), embedded verbatim
    /// in every track and written once as `cover.jpg` in the output folder.
    public var artworkJPEG: Data?

    /// Writes the `pgap` atom so Music plays the tracks back to back.
    public var gaplessAlbum: Bool

    /// Writes the `cpil` (compilation) flag.
    public var compilation: Bool

    public init(
        album: String = "",
        albumArtist: String = "",
        year: Int? = nil,
        genre: String? = nil,
        comment: String? = nil,
        artworkJPEG: Data? = nil,
        gaplessAlbum: Bool = true,
        compilation: Bool = false
    ) {
        self.album = album
        self.albumArtist = albumArtist
        self.year = year
        self.genre = genre
        self.comment = comment
        self.artworkJPEG = artworkJPEG
        self.gaplessAlbum = gaplessAlbum
        self.compilation = compilation
    }

    /// `true` when both required fields have non-whitespace content.
    public var isComplete: Bool {
        !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !albumArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
