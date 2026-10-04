//
//  ParseOptions.swift
//  SetSplitterCore
//
//  The semantic knobs the Tracklist screen exposes.
//  `Codable` so the user's last-used options persist in `UserDefaults`.
//

import Foundation

/// User-tunable parsing behaviour. Every field maps to one row of the Tracklist
/// screen's options panel; anything not in the panel stays out of v1.
public struct ParseOptions: Hashable, Sendable, Codable {

    /// Which side of the artist/title separator the artist is on.
    public enum FieldOrder: String, Sendable, Codable, CaseIterable {
        case artistThenTitle
        case titleThenArtist
    }

    /// How to pick the artist/title separator. `.auto` tries `" - "`, `" – "`,
    /// `" — "`, `" : "` in that priority order; the others force one character.
    public enum SeparatorMode: Hashable, Sendable, Codable {
        case auto
        case hyphen        // "-"
        case enDash        // "–"
        case emDash        // "—"
        case colon         // ":"
        case slash         // "/"
        case custom(String)
    }

    /// What to do with a segment that contains several `Artist - Title` entries
    /// joined by `W/` (or parallel titles joined by `vs.`).
    public enum MashupStrategy: String, Sendable, Codable, CaseIterable {
        /// Keep everything: artists joined with `&`, titles with `/`.
        case merge
        /// Drop entries after the first.
        case firstEntryOnly
    }

    /// What to do with audio before the first timestamp.
    public enum LeadInStrategy: String, Sendable, Codable, CaseIterable {
        /// Extend track 1 back to 0:00.
        case includeInFirstTrack
        /// Start track 1 at the first timestamp; the lead-in is discarded.
        case trim
    }

    /// Artist – Title vs. Title – Artist. Default `.artistThenTitle`.
    public var fieldOrder: FieldOrder

    /// Separator detection. Default `.auto`.
    public var separatorMode: SeparatorMode

    /// Mashup handling. Default `.merge`.
    public var mashupStrategy: MashupStrategy

    /// Treat a lowercase ` x ` as an artist separator. Default `false`.
    public var treatXAsArtistSeparator: Bool

    /// Lead-in handling. Default `.includeInFirstTrack`.
    public var leadInStrategy: LeadInStrategy

    /// Strip bracketed noise tags like `[Free Download]`, `(Free DL)`.
    /// Default `true`.
    public var stripBracketedTags: Bool

    public init(
        fieldOrder: FieldOrder = .artistThenTitle,
        separatorMode: SeparatorMode = .auto,
        mashupStrategy: MashupStrategy = .merge,
        treatXAsArtistSeparator: Bool = false,
        leadInStrategy: LeadInStrategy = .includeInFirstTrack,
        stripBracketedTags: Bool = true
    ) {
        self.fieldOrder = fieldOrder
        self.separatorMode = separatorMode
        self.mashupStrategy = mashupStrategy
        self.treatXAsArtistSeparator = treatXAsArtistSeparator
        self.leadInStrategy = leadInStrategy
        self.stripBracketedTags = stripBracketedTags
    }

    /// All defaults — the settings a first-time user sees.
    public static let `default` = ParseOptions()
}
