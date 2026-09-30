//
//  AudioInspecting.swift
//  SetSplitterCore
//

import AVFoundation

/// Inspects an audio file. Protocol so view models can be tested with stubs.
public protocol AudioInspecting: Sendable {
    func inspect(url: URL) async throws -> AudioSourceInfo
}
