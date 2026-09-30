//
//  CoverDesignControls.swift
//  SetSplitter
//
//  Generate mode's options under the preview: shuffle the gradient, swap it for a
//  photo, and (once there is a photo) pick a colour treatment that keeps the title readable.
//

import SwiftUI
import SetSplitterCore

struct CoverDesignControls: View {

    let model: ExportViewModel
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 10) {
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Shuffle", systemImage: "shuffle", action: model.shuffleColors)
                        .glassButtonStyle()
                        .help("Try a different gradient.")
                        .disabled(store.cover.background != nil && store.cover.filter != .duotone)   // only duotone shows the gradient's colours over a photo
                    Button(store.cover.background == nil ? "Add Photo…" : "Change…", systemImage: "photo") {
                        Task { await model.browseForArtwork() }
                    }
                    .glassButtonStyle()
                    .help("Use a photo behind the title instead of the gradient.")
                }
            }
            .controlSize(.regular)

            if let name = store.cover.backgroundName, store.cover.background != nil {
                HStack {
                    Text(name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 6)
                    Button("Remove", role: .destructive, action: model.removeBackground)
                        .buttonStyle(.link)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Picker("Filter", selection: $store.cover.filter) {
                    ForEach(CoverStyle.Filter.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .help("Tints the photo so the title stays readable. Duotone uses the gradient's colours.")
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("The title is drawn from the Album field. Add a photo to use instead of the gradient.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(Theme.smooth, value: store.cover.background != nil)
    }
}
