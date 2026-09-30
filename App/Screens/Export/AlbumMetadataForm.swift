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
                fieldRow("Genre", text: $store.genre)
                fieldRow("Comment", text: $store.comment, prompt: "Optional")
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

    /// Width of the label column, so every field's text starts at the same left edge.
    private static let labelWidth: CGFloat = 96

    /// One labelled text field. Its text is leading-aligned on purpose: AppKit doesn't lay out
    /// *trailing* whitespace in right-aligned text (a typed space stays invisible, and the caret
    /// doesn't move, until the next character), so a right-aligned field can't show "Chris " properly.
    private func fieldRow<Accessory: View>(
        _ title: String, text: Binding<String>, prompt: String? = nil, labelColor: Color = .primary,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(labelColor)
                .frame(width: Self.labelWidth, alignment: .leading)
            TextField(title, text: text, prompt: prompt.map { Text($0) })
                .labelsHidden()
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
            accessory()
        }
    }

    private var yearField: some View {
        @Bindable var store = store
        return fieldRow("Year", text: $store.yearText, prompt: "Optional",
                        labelColor: store.yearIsValid ? .primary : .red) {
            if !store.yearIsValid {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    .help("Enter a four-digit year, or leave it empty.")
            }
        }
        .animation(Theme.quick, value: store.yearIsValid)
    }

    private func requiredField(_ title: String, text: Binding<String>, help: String) -> some View {
        let isMissing = model.showsValidation && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return fieldRow(title, text: text, prompt: "Required", labelColor: isMissing ? .red : .primary) {
            if isMissing {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))
            }
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
