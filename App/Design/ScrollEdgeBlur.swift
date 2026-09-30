//
//  ScrollEdgeBlur.swift
//  SetSplitter
//
//  "There's more below": rows that are cut off by the bottom of a scroll view blur
//  (and dim slightly) in proportion to how much of them is hidden, and sharpen as
//  they scroll into full view. It's a plain blur of the row itself, with no tinted
//  overlay, so nothing is added over the content. Once the end of the list is in
//  view nothing blurs.
//
//  Two halves: the scroll view reports whether it can still scroll down
//  (`reportsMoreContentBelow`), and each row blurs itself using that flag
//  (`blursWhenCutOffAtBottom`).
//

import SwiftUI

extension View {

    /// Apply to the `ScrollView`. Keeps `hasMore` true while content extends past its bottom edge.
    func reportsMoreContentBelow(_ hasMore: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { geometry in
            // A few points of slack so rubber-banding at the very end doesn't flicker it back on.
            geometry.contentOffset.y + geometry.containerSize.height < geometry.contentSize.height - 6
        } action: { _, isCutOff in
            hasMore.wrappedValue = isCutOff
        }
    }

    /// Apply to each row inside the scroll view. While `active`, the row blurs as it is cut off by the
    /// scroll view's bottom edge: nothing when fully visible, full `radius` once `cutOffForFullBlur` points are hidden.
    /// Kept deliberately light: it's a hint that there's more, not an effect to look at.
    func blursWhenCutOffAtBottom(active: Bool, radius: CGFloat = 2, cutOffForFullBlur: CGFloat = 80) -> some View {
        visualEffect { content, proxy in
            let viewport = proxy.bounds(of: .scrollView)?.height ?? .infinity
            let hidden = proxy.frame(in: .scrollView).maxY - viewport
            let amount = active ? min(1, max(0, hidden / cutOffForFullBlur)) : 0
            return content
                .blur(radius: radius * amount)
                .opacity(1 - 0.25 * amount)
        }
    }
}
