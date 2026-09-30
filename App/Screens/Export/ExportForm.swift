//
//  ExportForm.swift
//  SetSplitter
//
//  Artwork on the left; album details and the destination on the right in a
//  native grouped form.
//

import SwiftUI
import SetSplitterCore

struct ExportForm: View {

    let model: ExportViewModel
    @Environment(SessionStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            ArtworkPicker(model: model)
                .frame(width: 250)
                .padding(.top, 10)   // lines the "Artwork" label up with the form's first section header

            VStack(alignment: .leading, spacing: 10) {
                AlbumMetadataForm(model: model)
                summary.padding(.leading, 20)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// One line of what is about to happen.
    private var summary: some View {
        let count = store.exportPlan?.tracks.count ?? 1
        return HStack(spacing: 6) {
            Image(systemName: "waveform.badge.checkmark")
            Text("\(count) \(count == 1 ? "track" : "tracks") · \(ExportSettings.Codec.aac(bitrateKbps: 256).displayName) · gapless")
                .contentTransition(.numericText())
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .help("AAC plays gaplessly in Music. With iCloud Music Library on, Apple re-encodes uploads to AAC 256 anyway.")
        .padding(.horizontal, 4)
    }
}
