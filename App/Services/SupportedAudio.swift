//
//  SupportedAudio.swift
//  SetSplitter
//
//  implementation.md §1: the accepted input types live in one place so adding
//  `.wav`, `.flac`, `.m4a`, `.aiff` later is a one-line change.
//

import Foundation
import UniformTypeIdentifiers

enum SupportedAudio {

    /// Content types the drop zone and open panel accept. Widen this list (or
    /// swap for `.audio`) to support more input formats.
    static let contentTypes: [UTType] = [.mp3]

    /// Human-readable list for empty-state copy.
    static let displayName = "MP3"

    static func accepts(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return contentTypes.contains { type.conforms(to: $0) }
    }
}
