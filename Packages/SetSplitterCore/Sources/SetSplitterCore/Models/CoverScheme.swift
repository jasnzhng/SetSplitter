//
//  CoverScheme.swift
//  SetSplitterCore
//
//  The curated gradient pairs behind every generated cover, big (the album art)
//  and small (each track's mini cover). A fixed list — not random hues — keeps
//  everything the app makes looking like it came from one label.
//

import Foundation

public struct CoverScheme: Hashable, Sendable {

    public let top: RGBColor
    public let bottom: RGBColor

    public static let all: [CoverScheme] = [
        CoverScheme(top: RGBColor(red: 1.00, green: 0.42, blue: 0.30), bottom: RGBColor(red: 0.42, green: 0.25, blue: 0.63)),
        CoverScheme(top: RGBColor(red: 0.98, green: 0.72, blue: 0.36), bottom: RGBColor(red: 0.90, green: 0.30, blue: 0.42)),
        CoverScheme(top: RGBColor(red: 0.30, green: 0.78, blue: 0.75), bottom: RGBColor(red: 0.20, green: 0.24, blue: 0.62)),
        CoverScheme(top: RGBColor(red: 0.62, green: 0.45, blue: 1.00), bottom: RGBColor(red: 0.98, green: 0.42, blue: 0.62)),
        CoverScheme(top: RGBColor(red: 0.96, green: 0.84, blue: 0.50), bottom: RGBColor(red: 0.86, green: 0.44, blue: 0.30)),
        CoverScheme(top: RGBColor(red: 0.36, green: 0.62, blue: 0.98), bottom: RGBColor(red: 0.56, green: 0.30, blue: 0.80)),
        CoverScheme(top: RGBColor(red: 0.40, green: 0.82, blue: 0.56), bottom: RGBColor(red: 0.14, green: 0.42, blue: 0.50)),
        CoverScheme(top: RGBColor(red: 0.98, green: 0.56, blue: 0.44), bottom: RGBColor(red: 0.62, green: 0.20, blue: 0.40)),
    ]

    /// The scheme a seed string always maps to.
    public static func scheme(forSeed seed: String) -> CoverScheme {
        all[Int(StableHash.fnv1a(seed) % UInt64(all.count))]
    }
}
