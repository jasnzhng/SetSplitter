//
//  AlbumNameGuesser.swift
//  SetSplitterCore
//
//  "Album = last folder-ish guess from the filename".
//

import Foundation

public enum AlbumNameGuesser {

    /// `"Tomorrowland_2026-Mainstage.mp3"` → `"Tomorrowland 2026-Mainstage"`.
    /// Drops the extension, turns underscores into spaces, collapses whitespace.
    public static func guess(fromFilename filename: String) -> String {
        let stem = (filename as NSString).deletingPathExtension
        let spaced = stem.replacingOccurrences(of: "_", with: " ")
        return spaced.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
