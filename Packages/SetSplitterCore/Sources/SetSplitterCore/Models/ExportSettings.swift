//
//  ExportSettings.swift
//  SetSplitterCore
//
//  implementation.md §4. v1 ships AAC only (CLAUDE.md decision log): the
//  `.alac` case is kept so a Phase 7 ALAC path doesn't reshape the API, but
//  nothing wires it up and no UI exposes it.
//

import Foundation

/// How the output folder and its files are produced.
public struct ExportSettings: Hashable, Sendable {

    public enum Codec: Hashable, Sendable {
        case aac(bitrateKbps: Int)
        case alac
    }

    /// What to do when `outputDirectory/folderName` already exists.
    public enum ExistingFolderPolicy: Hashable, Sendable {
        /// Throw `ExportError.destinationExists`; the caller asks the user.
        case fail
        /// Move the existing folder to the Trash, then write.
        case replace
        /// Write to `"<name> (2)"`, `"(3)"`, … instead.
        case keepBoth
    }

    public var codec: Codec

    /// The user's chosen *parent* folder. The album folder is created inside.
    public var outputDirectory: URL

    /// Album folder name, e.g. `"Artist - Album"`. Sanitised on use.
    public var folderName: String

    public var filenameTemplate: FilenameTemplate

    public var existingFolderPolicy: ExistingFolderPolicy

    public init(
        codec: Codec = .aac(bitrateKbps: 256),
        outputDirectory: URL,
        folderName: String,
        filenameTemplate: FilenameTemplate = .numberArtistTitle,
        existingFolderPolicy: ExistingFolderPolicy = .fail
    ) {
        self.codec = codec
        self.outputDirectory = outputDirectory
        self.folderName = folderName
        self.filenameTemplate = filenameTemplate
        self.existingFolderPolicy = existingFolderPolicy
    }
}
