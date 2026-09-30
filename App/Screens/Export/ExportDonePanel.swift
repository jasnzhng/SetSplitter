//
//  ExportDonePanel.swift
//  SetSplitter
//
//  Success state: where the album went, how to add it to Music, and anything
//  the planner had to drop along the way.
//

import SwiftUI
import SetSplitterCore

struct ExportDonePanel: View {

    let result: ExportResult
    let onReveal: () -> Void
    let onEdit: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
                .symbolEffect(.bounce, value: appeared)
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("Your album is ready")
                    .font(.system(size: 26, weight: .semibold))
                Text("\(result.files.count) \(result.files.count == 1 ? "track" : "tracks") written to")
                    .foregroundStyle(.secondary)
                Text((result.folder.path as NSString).abbreviatingWithTildeInPath)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 480)
            }

            HStack(spacing: 10) {
                Button("Reveal in Finder", systemImage: "folder", action: onReveal)
                    .buttonStyle(.borderedProminent)
                Button("Back to Settings", action: onEdit)
            }
            .controlSize(.large)

            WarningsList(warnings: result.warnings)
                .frame(maxWidth: 480)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "music.note.list").foregroundStyle(.secondary)
                Text("In Music, choose File ▸ Add to Library… and pick the folder. The tracks appear as one album and play without gaps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: 480)
            .card(radius: 10)
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { withAnimation(.spring(duration: 0.55, bounce: 0.4)) { appeared = true } }
    }
}
