//
//  ArtworkPicker.swift
//  SetSplitter
//
//  Album art, two ways. Generate (the default) draws the album title over a
//  gradient or a photo and re-renders live as the title is edited; Upload uses
//  the user's own image as-is, or none at all. An uploaded image is prepared
//  (square crop, ≤1400 px JPEG) immediately so the preview shows exactly what
//  gets embedded.
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

            Picker("Artwork source", selection: mode) {
                Text("Generate").tag(ArtworkMode.generate)
                Text("Upload").tag(ArtworkMode.upload)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            ArtworkPreview(
                image: store.artwork?.image, isTargeted: isTargeted,
                onChooseWhenEmpty: store.artworkMode == .upload ? { Task { await model.browseForArtwork() } } : nil)
                .animation(Theme.smooth, value: store.artwork?.jpeg.count)
                .fileDropTarget(isTargeted: $isTargeted) { urls in
                    guard let url = urls.first else { return }
                    Task { await model.useImage(from: url) }
                }

            switch store.artworkMode {
            case .generate: CoverDesignControls(model: model)
            case .upload: uploadControls
            }

            if let error = model.artworkError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        // Generate is the default, so the first visit renders straight away; after that it follows the title live.
        .task { if store.artworkMode == .generate, store.artwork == nil { model.refreshCover(debounced: false) } }
        .onChange(of: store.albumTitle) { model.refreshCover() }
        .onChange(of: store.cover.filter) { model.refreshCover(debounced: false) }
    }

    private var mode: Binding<ArtworkMode> {
        Binding(get: { store.artworkMode }, set: { model.setArtworkMode($0) })
    }

    // MARK: Upload

    @ViewBuilder
    private var uploadControls: some View {
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
                Button("Choose Image…") { Task { await model.browseForArtwork() } }
                    .glassButtonStyle()
            }
            .controlSize(.regular)
            Text("Use your own artwork instead of a generated cover. Optional: with none, tracks are saved without art.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
