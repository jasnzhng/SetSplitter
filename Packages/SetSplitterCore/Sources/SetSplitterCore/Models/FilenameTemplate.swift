//
//  FilenameTemplate.swift
//  SetSplitterCore
//

import Foundation

/// Track filename layout.
public enum FilenameTemplate: String, Hashable, Sendable, CaseIterable {
    /// `01 Artist - Title.m4a`; `01 Title.m4a` when the artist is empty.
    case numberArtistTitle
    /// `01 Title.m4a`
    case numberTitle
}
