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

    /// The spring used for every state change so motion feels like one system.
    static let spring = Animation.smooth(duration: 0.38)
    static let quick = Animation.snappy(duration: 0.22)
}

extension View {

    /// A quiet elevated surface: control-background fill, hairline separator.
    func card(radius: CGFloat = Theme.cardRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
        )
    }
}

/// Small uppercase section label used above cards.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}
