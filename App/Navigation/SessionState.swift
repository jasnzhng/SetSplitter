//
//  SessionState.swift
//  SetSplitter
//
//  Small value types that `SessionStore` holds. Kept apart so the store file
//  stays about state and rules, not type declarations.
//

import AppKit
import Foundation
import SetSplitterCore

/// The imported audio file, with its inspection result and the sandbox access
/// that must stay alive until the export finishes.
struct SourceFile {
    let url: URL
    let info: AudioSourceInfo
    let access: SecurityScopedAccess

    var filename: String { url.lastPathComponent }
}

/// Prepared album artwork (already JPEG, ≤ 1400 px, square), with the decoded image and the
/// colours pulled from it, computed once so views never decode in `body`.
struct Artwork {
    let jpeg: Data
    let pixelSize: Int
    let notices: [PreparedArtwork.Notice]
    let palette: [SRGBColor]
    let image: NSImage?

    init(prepared: PreparedArtwork, palette: [SRGBColor]) {
        self.jpeg = prepared.jpeg
        self.pixelSize = prepared.pixelSize
        self.notices = prepared.notices
        self.palette = palette
        self.image = NSImage(data: prepared.jpeg)
    }
}

/// Where the album art comes from.
enum ArtworkMode: Hashable {
    /// Made from the album title over a gradient or a background photo.
    case generate
    /// The user's own image, used as-is (or none at all).
    case upload
}

/// The Generate mode's settings. The title comes from the album field, so typing there re-renders live.
struct CoverDesign: Equatable {
    /// Which gradient; a random one to start, and "Shuffle" picks another.
    var schemeIndex = Int.random(in: 0..<CoverScheme.all.count)
    /// The chosen background photo, already prepared (square JPEG ≤ 1400 px). `nil` = use the gradient.
    var background: Data?
    var backgroundName: String?
    var filter: CoverStyle.Filter = .none
    var text = CoverTextStyle()

    var style: CoverStyle { CoverStyle(schemeIndex: schemeIndex, background: background, filter: filter, text: text) }
}

extension CoverStyle.Filter {
    var displayName: String {
        switch self {
        case .none: "None"
        case .darken: "Darken"
        case .greyscale: "Greyscale"
        case .duotone: "Duotone"
        }
    }
}

/// Where the album folder will be created.
struct OutputFolder {
    let url: URL
    /// Keeps the sandbox grant alive; `nil` only in tests.
    let access: SecurityScopedAccess?
}

/// Lifecycle of the export screen.
enum ExportState {
    case idle
    case running(ExportProgress)
    case finished(ExportResult)
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}
