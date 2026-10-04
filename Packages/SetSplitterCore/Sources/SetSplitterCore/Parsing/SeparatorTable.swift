//
//  SeparatorTable.swift
//  SetSplitterCore
//
//  Every marker string the parser
//  recognises lives here as a static array with a comment per entry. Adding a
//  marker is a one-line change — no new branch anywhere else.
//
//  Matching rules (applied by the stages, not here):
//   * all markers are matched case-insensitively; artist/title separators
//     include their surrounding spaces (" - "), so hyphenated names survive
//   * artist / title / feat markers are only recognised at paren/bracket
//     depth 0 (see DepthAwareSplitter)
//   * NEVER split an artist on "&", "and", or "," — those are deliberately
//     absent from `artistSeparators`
//

import Foundation

/// Central registry of parser marker strings. Pure data.
enum SeparatorTable {

    // MARK: Artist/title separators (primary split)

    /// Candidate separators between the artist side and the title side, in
    /// auto-detection priority order. The parser picks the first one present.
    static let artistTitleSeparators: [String] = [
        " - ",   // hyphen-minus with spaces — by far the most common
        " – ",   // en dash (U+2013), often from "smart" text
        " — ",   // em dash (U+2014)
        " : ",   // colon, seen in some YouTube-comment lists
    ]

    // (Forced single-character separators are expanded to spacing variants in
    //  `CreditParser.primarySeparatorCandidates`, keyed off
    //  `ParseOptions.SeparatorMode` directly.)

    // MARK: Entry separators (mashups by W/)

    /// Slash-form markers that join several complete `Artist - Title` entries
    /// inside one timestamped segment. They split the segment into entries;
    /// they never create a new track.
    static let entrySeparators: [String] = [
        "W/",     // canonical DJ-set "with" / mashup marker
        "w/",     // lowercase variant
    ]

    // (The spelled-out "with" separator needs a lookahead for a following `|`, so it
    //  lives as a regex in `EntrySplitter` rather than as a plain string here.)

    // MARK: Artist-side separators

    /// Markers that split the artist side into multiple artists. Whole-word,
    /// case-insensitive. `" x "` is included but gated behind
    /// `ParseOptions.treatXAsArtistSeparator` (default off).
    static let artistSeparators: [String] = [
        "ft.",        // featured-artist, abbreviated with dot
        "ft",         // featured-artist, bare
        "feat.",      // featured-artist, longer abbreviation with dot
        "feat",       // featured-artist, bare
        "featuring",  // featured-artist, spelled out
        "vs.",        // versus, with dot
        "vs",         // versus, bare
        "versus",     // versus, spelled out
        // "&", "and", "," are intentionally NOT here — see file header.
    ]

    /// Only added to `artistSeparators` when the user opts in.
    static let optionalArtistSeparatorX = " x "  // lowercase x as a collab marker

    // MARK: Title-side separators

    /// Markers that split the title side into parallel mashup titles. A strict
    /// subset of the artist separators — only "versus" forms.
    static let titleSeparators: [String] = [
        "vs.",     // versus, with dot
        "vs",      // versus, bare
        "versus",  // versus, spelled out
    ]

    // MARK: Featured-credit markers

    /// Inside a trailing `(...)` / `[...]` on the title side, these introduce a
    /// featured artist to pull out into `artists`. Remix / edit / bootleg /
    /// mashup credits use none of these words and stay in the title.
    static let featuredCreditMarkers: [String] = [
        "feat.",      // "(feat. X)"
        "feat",       // "(feat X)"
        "ft.",        // "(ft. X)"
        "ft",         // "(ft X)"
        "featuring",  // "(featuring X)"
    ]

    // MARK: Noise tags (gated by ParseOptions.stripBracketedTags)

    /// Bracketed tokens that are promotional noise, not part of a title.
    /// Compared case-insensitively against the *contents* of a `(...)` / `[...]`
    /// group after trimming.
    static let bracketedNoiseTags: [String] = [
        "free download",   // "[Free Download]"
        "free dl",         // "(Free DL)"
        "download",        // bare "[Download]"
        "buy",             // "[Buy]"
        "out now",         // "[OUT NOW]"
        "click buy for free download",
    ]
}
