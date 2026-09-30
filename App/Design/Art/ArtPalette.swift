//
//  ArtPalette.swift
//  SetSplitter
//
//  The colours behind the app's "artwork" look. Each wizard step has a resting
//  palette drawn from the app icon (coral, amber, plum, violet); once the user
//  picks cover art, the palette is taken from *that* image instead, so the whole
//  window becomes a piece of the album.
//

import SwiftUI

struct ArtPalette: Equatable {

    /// Three blob colours, in order of prominence.
    var colors: [Color]

    static let coral = Color(red: 1.00, green: 0.42, blue: 0.30)
    static let amber = Color(red: 1.00, green: 0.69, blue: 0.36)
    static let plum = Color(red: 0.42, green: 0.25, blue: 0.63)
    static let violet = Color(red: 0.48, green: 0.36, blue: 1.00)
    static let rose = Color(red: 1.00, green: 0.36, blue: 0.54)
    static let gold = Color(red: 1.00, green: 0.76, blue: 0.36)

    /// Resting palette for a wizard step.
    static func resting(for step: AppFlow.Step) -> ArtPalette {
        switch step {
        case .importFile: ArtPalette(colors: [coral, amber, plum])
        case .tracklist: ArtPalette(colors: [violet, coral, rose])
        case .export: ArtPalette(colors: [coral, plum, gold])
        }
    }
}
