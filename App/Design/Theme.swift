//
//  Theme.swift
//  SetSplitter
//
//  Shared design tokens. Colour comes from the system palette plus the single
//  asset-catalog accent (a warm vermilion, re-tuned for dark mode), so the app
//  follows light/dark automatically and never hard-codes a second brand colour.
//

import SwiftUI

enum Theme {
    static let pagePadding: CGFloat = 28
    static let cardRadius: CGFloat = 12
    static let rowRadius: CGFloat = 9

    /// The curve used for every larger state change so motion feels like one system.
    static let smooth = Animation.smooth(duration: 0.38)
    static let quick = Animation.snappy(duration: 0.22)
}

extension Font {

    /// Monospaced display face for headlines and big numerals: the studio-console / tracklist
    /// voice of the app. (Every large piece of type goes through here, so the face is one edit.)
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {

    /// The app's standard surface: a Liquid Glass panel.
    func card(radius: CGFloat = Theme.cardRadius) -> some View {
        glassSurface(cornerRadius: radius)
    }
}
