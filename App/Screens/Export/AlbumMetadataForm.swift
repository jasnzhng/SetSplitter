//
//  AlbumMetadataForm.swift
//  SetSplitter
//
//  Album-level tags and the output folder, in a grouped Form (the same look as
//  System Settings). Album and Album Artist are required; the artist is what
//  makes Music group the tracks into one album.
//

import SwiftUI
import SetSplitterCore

struct AlbumMetadataForm: View {

    let model: ExportViewModel
    @Environment(SessionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                requiredField("Album", text: $store.albumTitle, help: "The album title shown in Music.")
                requiredField("Album Artist", text: $store.albumArtist,
                              help: "Groups every track into one album in Music.")
                yearField
                TextField("Genre", text: $store.genre)
                TextField("Comment", text: $store.comment, prompt: Text("Optional"))
            } header: {
                Text("Album")
            }

            Section {
                folderRow
            } header: {
                Text("Save to")
            } footer: {
                if store.outputFolder != nil {
                    Text("Creates “\(ExportJob.destination(for: previewSettings).lastPathComponent)” inside this folder.")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)   // hug the rows instead of stretching
    }

    // MARK: Rows

    private var yearField: some View {
        @Bindable var store = store
        return LabeledContent {
            HStack(spacing: 6) {
                TextField("Year", text: $store.yearText, prompt: Text("Optional"))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                if !store.yearIsValid {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                        .help("Enter a four-digit year, or leave it empty.")
                }
            }
        } label: {
            Text("Year").foregroundStyle(store.yearIsValid ? Color.primary : Color.red)
        }
        .animation(Theme.quick, value: store.yearIsValid)
    }

    private func requiredField(_ title: String, text: Binding<String>, help: String) -> some View {
        let isMissing = model.showsValidation && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return LabeledContent {
            HStack(spacing: 6) {
                TextField(title, text: text, prompt: Text("Required"))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                if isMissing {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        } label: {
            Text(title).foregroundStyle(isMissing ? Color.red : Color.primary)
        }
        .help(help)
        .animation(Theme.quick, value: isMissing)
    }

    /// A plain HStack rather than `LabeledContent`, which would wrap a long
    /// path onto a second line; here the path truncates from the head instead.
    private var folderRow: some View {
        let isMissing = model.showsValidation && store.outputFolder == nil
        return HStack(spacing: 10) {
            Text("Folder").foregroundStyle(isMissing ? Color.red : Color.primary)
            Spacer(minLength: 12)
            Text(store.outputFolder.map { Self.displayPath($0.url) } ?? "No folder chosen")
                .foregroundStyle(isMissing ? Color.red : Color.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            Button("Choose…") { Task { await model.chooseFolder() } }
        }
        .animation(Theme.quick, value: isMissing)
    }

    /// Settings used only to preview the folder name the export would create.
    private var previewSettings: ExportSettings {
        ExportSettings(
            outputDirectory: store.outputFolder?.url ?? URL(fileURLWithPath: "/"),
            folderName: store.folderName, existingFolderPolicy: .fail)
    }

    /// `/Users/me/Music` → `~/Music`.
    private static func displayPath(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}
