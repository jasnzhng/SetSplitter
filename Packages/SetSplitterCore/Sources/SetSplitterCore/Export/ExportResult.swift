//
//  ExportResult.swift
//  SetSplitterCore
//

import Foundation

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
