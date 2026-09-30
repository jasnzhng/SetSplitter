//
//  ArtworkPreview.swift
//  SetSplitter
//
//  The square cover preview. It tilts toward the pointer like a sleeve in your
//  hands, and doubles as the empty / loading state when there is no image yet.
//

import SwiftUI

struct ArtworkPreview: View {

    let image: NSImage?
    /// A file is being dragged over the preview.
    let isTargeted: Bool
    /// With no image: makes the empty state a dashed "drop or click" target. `nil` shows a spinner instead
    /// (the generated cover is about to appear).
    var onChooseWhenEmpty: (() -> Void)?

    /// Pointer position over the artwork, -0.5…0.5 on each axis; drives the tilt.
    @State private var tilt: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .accessibilityLabel("Album artwork")
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 14 + abs(tilt.width) * 10, x: -tilt.width * 14, y: 6 + tilt.height * 8)
                    .rotation3DEffect(.degrees(tilt.height * -9), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(tilt.width * 11), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .onContinuousHover { phase in
                        guard !reduceMotion else { return }
                        withAnimation(.smooth(duration: 0.25)) {
                            switch phase {
                            case .active(let point): tilt = CGSize(width: point.x / 250 - 0.5, height: point.y / 250 - 0.5)
                            case .ended: tilt = .zero
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let onChooseWhenEmpty {
                Button(action: onChooseWhenEmpty) { emptyState }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Album artwork, empty. Choose an image.")
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay { ProgressView().controlSize(.small) }
                    .accessibilityLabel("Generating artwork")
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            // Drop feedback when there *is* an image underneath (the empty state draws its own).
            if isTargeted, image != nil {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isTargeted ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.25, dash: isTargeted ? [] : [7, 5]))
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                        .symbolEffect(.bounce, value: isTargeted)
                    Text("Drop cover art")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .scaleEffect(isTargeted ? 1.02 : 1)
            .animation(Theme.smooth, value: isTargeted)
    }
}
