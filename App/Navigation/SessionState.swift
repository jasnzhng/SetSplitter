//
//  SessionState.swift
//  SetSplitter
//
//  Small value types that `SessionStore` holds. Kept apart so the store file
//  stays about state and rules, not type declarations.
//

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

/// Prepared album artwork (already JPEG, ≤ 1400 px, square).
struct Artwork {
    let jpeg: Data
    let pixelSize: Int
    let notices: [PreparedArtwork.Notice]
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
