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
    @State private var isTextExpanded = Self.startsWithTextExpanded

    #if DEBUG
    /// Snapshot harness hook: open the Text group so it can be reviewed.
    @MainActor static var startsWithTextExpanded = false
    #else
    private static let startsWithTextExpanded = false
    #endif

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

            textControls
        }
        .animation(Theme.smooth, value: store.cover.background != nil)
    }

    // MARK: Text

    /// Label column shared by every row in the group, wide enough for "Lines" / "Place" without wrapping.
    private static let labelWidth: CGFloat = 48

    private var textControls: some View {
        @Bindable var store = store
        return DisclosureGroup("Text", isExpanded: $isTextExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                row("Size") {
                    Slider(value: $store.cover.text.size, in: CoverTextStyle.sizeRange)
                }
                row("Lines") {
                    Slider(value: $store.cover.text.lineSpacing, in: CoverTextStyle.lineSpacingRange)
                }
                row("Align") {
                    Picker("Align", selection: $store.cover.text.alignment) {
                        Image(systemName: "text.alignleft").tag(CoverTextStyle.Alignment.leading)
                        Image(systemName: "text.aligncenter").tag(CoverTextStyle.Alignment.center)
                        Image(systemName: "text.alignright").tag(CoverTextStyle.Alignment.trailing)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .help("Align the title left, centre or right.")
                }
                row("Place") {
                    Picker("Place", selection: $store.cover.text.position) {
                        Text("Top").tag(CoverTextStyle.Position.top)
                        Text("Middle").tag(CoverTextStyle.Position.middle)
                        Text("Bottom").tag(CoverTextStyle.Position.bottom)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .help("Where the title sits on the cover.")
                }

                HStack {
                    Toggle("Shadow", isOn: $store.cover.text.shadow)
                        .toggleStyle(.checkbox)
                        .help("A soft shadow behind the letters, for readability over photos.")
                    Spacer()
                    Button("Reset") { store.cover.text = CoverTextStyle() }
                        .buttonStyle(.link)
                        .disabled(store.cover.text == CoverTextStyle())
                }
            }
            .font(.callout)
            .padding(.top, 8)
        }
        .font(.callout)
    }

    /// A label in a fixed column (never wrapped) with its control filling the rest of the row.
    private func row<Control: View>(_ title: String, @ViewBuilder _ control: () -> Control) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .lineLimit(1)
                .frame(width: Self.labelWidth, alignment: .leading)
            control()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
