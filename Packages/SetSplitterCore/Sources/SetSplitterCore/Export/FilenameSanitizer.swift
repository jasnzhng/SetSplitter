//
//  FilenameSanitizer.swift
//  SetSplitterCore
//
//  Turns arbitrary track text into safe file names.
//

import Foundation

/// Builds Finder-safe file names from artist/title text.
public enum FilenameSanitizer {

    /// Longest file name we emit, in UTF-8 bytes (HFS+/APFS allow 255).
    public static let maxBytes = 200

    /// Zero-width and bidi-control scalars that are invisible in Finder but
    /// make names look identical yet differ. U+200D (ZWJ) is deliberately
    /// absent: it glues emoji sequences like 👨‍👩‍👧 together.
    private static let invisibles: Set<Unicode.Scalar> = [
        "\u{200B}", "\u{200C}", "\u{200E}", "\u{200F}", "\u{2060}", "\u{FEFF}",
        "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}",
    ]

    /// Sanitises one path component (no extension): `/` and `:` become `-`,
    /// control characters are dropped, whitespace collapses, leading dots and
    /// surrounding spaces/dots are stripped.
    public static func sanitize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar {
            case "/", ":", "\\":
                scalars.append("-")
            case _ where scalar.properties.isWhitespace:
                scalars.append(" ")   // checked before `.control`: tab and newline are both
            case _ where scalar.properties.generalCategory == .control:
                continue
            case _ where invisibles.contains(scalar):
                continue
            default:
                scalars.append(scalar)
            }
        }
        var s = String(scalars)
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        while s.hasPrefix(".") || s.hasPrefix(" ") { s.removeFirst() }
        while s.hasSuffix(".") || s.hasSuffix(" ") { s.removeLast() }
        return s
    }

    /// `"01 Artist - Title.m4a"`, truncated so the whole name (extension
    /// included) fits in `maxBytes`, cutting only on grapheme boundaries.
    public static func filename(
        number: Int,
        artist: String,
        title: String,
        template: FilenameTemplate,
        fileExtension: String = "m4a"
    ) -> String {
        let a = sanitize(artist)
        let t = sanitize(title)
        let prefix = String(format: "%02d", number)

        var stem: String
        switch template {
        case .numberArtistTitle:
            stem = a.isEmpty ? "\(prefix) \(t)" : "\(prefix) \(a) - \(t)"
        case .numberTitle:
            stem = "\(prefix) \(t)"
        }
        stem = stem.trimmingCharacters(in: .whitespaces)
        return truncate(stem: stem, fileExtension: fileExtension)
    }

    /// Makes names unique (case-insensitively — APFS is case-insensitive by
    /// default) by inserting `" (2)"`, `" (3)"`, … before the extension.
    public static func uniqued(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.map { name in
            var candidate = name
            var n = 2
            let ns = name as NSString
            let ext = ns.pathExtension
            let stem = ns.deletingPathExtension
            while seen.contains(candidate.lowercased()) {
                candidate = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
                n += 1
            }
            seen.insert(candidate.lowercased())
            return candidate
        }
    }

    // MARK: Truncation

    private static func truncate(stem: String, fileExtension: String) -> String {
        let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
        // Reserve room for a " (99)" collision suffix as well.
        let budget = maxBytes - suffix.utf8.count - 5
        var result = ""
        var used = 0
        for character in stem {
            let size = String(character).utf8.count
            if used + size > budget { break }
            result.append(character)
            used += size
        }
        result = result.trimmingCharacters(in: .whitespaces)
        return result + suffix
    }
}
