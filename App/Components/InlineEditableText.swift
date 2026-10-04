//
//  InlineEditableText.swift
//  SetSplitter
//
//  Text that becomes a text field on click. Return commits,
//  Escape cancels, and clicking elsewhere commits — the same contract as
//  renaming a file in Finder.
//

import SwiftUI

struct InlineEditableText: View {

    let text: String
    let placeholder: String
    var font: Font = .body
    var color: Color = .primary
    let onCommit: (String) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if isEditing {
                TextField(placeholder, text: $draft)
                    .textFieldStyle(.plain)
                    .font(font)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onExitCommand { isEditing = false }   // Escape: discard
                    .onChange(of: isFocused) { _, focused in
                        if !focused, isEditing { commit() }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.accentColor, lineWidth: 1.5))
            } else {
                Button(action: beginEditing) {
                    Text(text.isEmpty ? placeholder : text)
                        .font(font)
                        .foregroundStyle(text.isEmpty ? Color.secondary.opacity(0.7) : color)
                        .italic(text.isEmpty)
                        .lineLimit(1)
                        .truncationMode(.middle)   // long mashup credits keep both ends visible
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primary.opacity(isHovering ? 0.07 : 0)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
                .help("Click to edit")
                .accessibilityHint("Edits this field")
            }
        }
        .padding(.horizontal, -5)   // keep text aligned with siblings despite the edit padding
        .animation(Theme.quick, value: isHovering)
    }

    private func beginEditing() {
        draft = text
        isEditing = true
        isFocused = true
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        if draft != text { onCommit(draft) }
    }
}
