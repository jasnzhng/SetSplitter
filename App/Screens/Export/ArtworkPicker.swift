//
//  ArtworkPicker.swift
//  SetSplitter
//
//  Drop or browse for album art. The picked image is prepared (square crop,
//  ≤1400 px JPEG) immediately so the preview shows exactly what gets embedded.
//

import SwiftUI
import SetSplitterCore

struct ArtworkPicker: View {

    let model: ExportViewModel
    @Environment(SessionStore.self) private var store
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Artwork")

            ZStack {
                if let art = store.artwork, let image = art.image {
                    Image(nsImage: image)
                        .resizable()
                        .accessibilityLabel("Album artwork")
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    Button { Task { await model.browseForArtwork() } } label: { placeholder }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Album artwork, empty. Choose an image.")
                        .transition(.opacity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .animation(Theme.smooth, value: store.artwork?.jpeg.count)
            .fileDropTarget(isTargeted: $isTargeted) { urls in
                guard let url = urls.first else { return }
                Task { await model.loadArtwork(from: url) }
            }
            .accessibilityElement(children: .contain)

            if let art = store.artwork {
                HStack {
                    Text("\(art.pixelSize) × \(art.pixelSize)")
                        .monospacedDigit()
                    Spacer()
                    Button("Replace…") { Task { await model.browseForArtwork() } }
                    Button("Remove", role: .destructive, action: model.removeArtwork)
                }
                .buttonStyle(.link)
                .font(.caption)
                notices(art)
            } else {
                GlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Choose Image…") { Task { await model.browseForArtwork() } }
                            .glassButtonStyle()
                        Button("Generate", systemImage: "sparkles") { Task { await model.generateCover() } }
                            .glassButtonStyle()
                            .help("Make a cover from this set: its title, artist and the shape of its tracklist.")
                    }
                }
                .controlSize(.regular)
                Text("Optional. Embedded in every track and saved as cover.jpg. No art? Generate one from the set.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = model.artworkError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var placeholder: some View {
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

    @ViewBuilder
    private func notices(_ art: Artwork) -> some View {
        ForEach(art.notices, id: \.self) { notice in
            Label {
                switch notice {
                case .croppedToSquare: Text("Cropped to a square from the center.")
                case .lowResolution(let px): Text("Only \(px) px — it may look soft. 600 px or more is best.")
                }
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
