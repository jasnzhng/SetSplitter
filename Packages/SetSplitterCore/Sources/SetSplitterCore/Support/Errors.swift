//
//  Errors.swift
//  SetSplitterCore
//
//  Typed errors with user-facing `errorDescription`,
//  one enum per subsystem. Cancellation is *not* an error case — it surfaces
//  as Swift's `CancellationError`.
//

import Foundation

/// Failures while inspecting the source audio.
public enum InspectionError: Error, LocalizedError, Equatable {
    case unreadable(String)
    case noAudioTrack
    case emptyAudio
    case unsupportedChannels(Int)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let detail):
            return "This file couldn't be opened as audio. \(detail)"
        case .noAudioTrack:
            return "This file doesn't contain an audio track."
        case .emptyAudio:
            return "This audio file appears to be empty."
        case .unsupportedChannels(let count):
            return "This file has \(count) audio channels; only mono and stereo are supported."
        }
    }
}

/// Failures while preparing album artwork.
public enum ArtworkError: Error, LocalizedError, Equatable {
    case undecodable
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .undecodable:
            return "That file couldn't be read as an image."
        case .encodingFailed:
            return "The artwork couldn't be converted to JPEG."
        }
    }
}

/// Failures while splitting, tagging and writing tracks.
public enum ExportError: Error, LocalizedError, Equatable {
    case destinationExists(URL)
    case cannotCreateFolder(String)
    case diskFull
    case readerFailed(String)
    case writerFailed(String)
    case sourceEndedEarly(track: Int)
    case emptyPlan

    public var errorDescription: String? {
        switch self {
        case .destinationExists(let url):
            return "A folder named “\(url.lastPathComponent)” already exists in that location."
        case .cannotCreateFolder(let detail):
            return "The output folder couldn't be created. \(detail)"
        case .diskFull:
            return "The disk ran out of space. Partial files were removed."
        case .readerFailed(let detail):
            return "Reading the source audio failed. \(detail)"
        case .writerFailed(let detail):
            return "Writing a track failed. \(detail)"
        case .sourceEndedEarly(let track):
            return "The audio ended before track \(track) began. Check that the tracklist timestamps fit the file."
        case .emptyPlan:
            return "There are no tracks to export."
        }
    }
}
