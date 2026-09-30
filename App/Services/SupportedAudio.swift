//
//  SupportedAudio.swift
//  SetSplitter
//
//  implementation.md §1: the accepted input types live in one place so adding
//  another format later (`.aiff`, `.flac`) is a one-line change. The Core
//  splitter is format-agnostic: `AVAssetReader` decodes whatever AVFoundation
//  can read to float PCM, so this list is the only gate.
//

import Foundation
import UniformTypeIdentifiers

enum SupportedAudio {

    /// Content types the drop zone and open panel accept. `.mpeg4Audio` covers
    /// `.m4a`; `accepts(_:)` matches by conformance, so aliases are included.
    static let contentTypes: [UTType] = [.mp3, .mpeg4Audio, .wav]

    /// Human-readable list for empty-state copy; reads after "a"/"an" ("an MP3, M4A or WAV file").
    static let displayName = "MP3, M4A or WAV"

    static func accepts(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return contentTypes.contains { type.conforms(to: $0) }
    }
}
