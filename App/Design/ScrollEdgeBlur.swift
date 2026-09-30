//
//  ScrollEdgeBlur.swift
//  SetSplitter
//
//  A soft frosted fade over the bottom edge of a scroll view, shown only while
//  there is more content below the fold. It says "keep scrolling" without a
//  scrollbar, and disappears once the end is in view.
//

import SwiftUI

extension View {

    /// Blurs and fades the bottom `height` points of a scroll view while it can still scroll down.
    /// Apply it to the `ScrollView` itself.
    func moreBelowBlur(height: CGFloat = 44) -> some View {
        modifier(MoreBelowBlur(height: height))
    }
}

private struct MoreBelowBlur: ViewModifier {

    let height: CGFloat
    @State private var hasMoreBelow = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                // A few points of slack so rubber-banding at the very end doesn't flicker it back on.
                geometry.contentOffset.y + geometry.containerSize.height < geometry.contentSize.height - 6
            } action: { _, isCutOff in
                hasMoreBelow = isCutOff
            }
            .overlay(alignment: .bottom) {
                if hasMoreBelow {
                    // A material blurs whatever is behind it; the gradient mask feathers it in from clear.
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                        .frame(height: height)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .animation(Theme.smooth, value: hasMoreBelow)
    }
}
