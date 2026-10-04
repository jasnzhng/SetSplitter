//
//  ParseOptionsPanel.swift
//  SetSplitter
//
//  The parse options as a compact control grid. Every row edits one field
//  of `ParseOptions`; the store persists and re-parses on change.
//

import SwiftUI
import SetSplitterCore

struct ParseOptionsPanel: View {

    @Binding var options: ParseOptions

    /// Backing text for the "Custom…" separator so typing doesn't fight the picker.
    @State private var customSeparator = ""

    /// Whether the picker is on "Custom…". Tracked separately from `options`
    /// because an empty custom separator is meaningless and is stored as `.auto`.
    @State private var isCustom = false

    private enum SeparatorChoice: Hashable {
        case auto, hyphen, enDash, emDash, colon, slash, custom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Options")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                row("Order") {
                    Picker("Order", selection: $options.fieldOrder) {
                        Text("Artist – Title").tag(ParseOptions.FieldOrder.artistThenTitle)
                        Text("Title – Artist").tag(ParseOptions.FieldOrder.titleThenArtist)
                    }
                    .labelsHidden()
                }
                row("Separator") {
                    HStack(spacing: 6) {
                        Picker("Separator", selection: separatorChoice) {
                            Text("Auto-detect").tag(SeparatorChoice.auto)
                            Divider()
                            Text("Hyphen  -").tag(SeparatorChoice.hyphen)
                            Text("En dash  –").tag(SeparatorChoice.enDash)
                            Text("Em dash  —").tag(SeparatorChoice.emDash)
                            Text("Colon  :").tag(SeparatorChoice.colon)
                            Text("Slash  /").tag(SeparatorChoice.slash)
                            Text("Custom…").tag(SeparatorChoice.custom)
                        }
                        .labelsHidden()
                        if separatorChoice.wrappedValue == .custom {
                            TextField("text", text: $customSeparator)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                                .onChange(of: customSeparator) { _, new in
                                    if !new.isEmpty { options.separatorMode = .custom(new) }
                                }
                        }
                    }
                }
                row("Mashups") {
                    Picker("Mashups", selection: $options.mashupStrategy) {
                        Text("Merge into one song").tag(ParseOptions.MashupStrategy.merge)
                        Text("Keep first entry only").tag(ParseOptions.MashupStrategy.firstEntryOnly)
                    }
                    .labelsHidden()
                }
                row("Before first time") {
                    Picker("Audio before first timestamp", selection: $options.leadInStrategy) {
                        Text("Include in track 1").tag(ParseOptions.LeadInStrategy.includeInFirstTrack)
                        Text("Trim it").tag(ParseOptions.LeadInStrategy.trim)
                    }
                    .labelsHidden()
                }
                GridRow {
                    Color.clear.frame(width: 0, height: 0)
                    HStack(spacing: 16) {
                        Toggle("Strip [Free Download] tags", isOn: $options.stripBracketedTags)
                        Toggle("Treat “x” as separator", isOn: $options.treatXAsArtistSeparator)
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .controlSize(.small)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .onAppear { syncCustomText() }
    }

    private func row<Control: View>(_ label: String, @ViewBuilder _ control: () -> Control) -> some View {
        GridRow {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            control()
        }
    }

    // MARK: Separator mapping

    private var separatorChoice: Binding<SeparatorChoice> {
        Binding(
            get: { () -> SeparatorChoice in
                if isCustom { return .custom }
                switch options.separatorMode {
                case .auto: return .auto
                case .hyphen: return .hyphen
                case .enDash: return .enDash
                case .emDash: return .emDash
                case .colon: return .colon
                case .slash: return .slash
                case .custom: return .custom
                }
            },
            set: { choice in
                isCustom = choice == .custom
                switch choice {
                case .auto: options.separatorMode = .auto
                case .hyphen: options.separatorMode = .hyphen
                case .enDash: options.separatorMode = .enDash
                case .emDash: options.separatorMode = .emDash
                case .colon: options.separatorMode = .colon
                case .slash: options.separatorMode = .slash
                case .custom: options.separatorMode = customSeparator.isEmpty ? .auto : .custom(customSeparator)
                }
            })
    }

    private func syncCustomText() {
        if case .custom(let text) = options.separatorMode { customSeparator = text; isCustom = true }
    }
}
