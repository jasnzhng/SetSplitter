//
//  ExportFinishedSummary.swift
//  SetSplitter
//
//  The details that fade in beside the finished sleeve: where the album went, how to
//  add it to Music, and anything the planner had to drop along the way.
//

import SwiftUI
import SetSplitterCore

struct ExportFinishedSummary: View {

    let result: ExportResult
    let onReveal: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your album is ready")
                    .font(.display(30))
                Text("\(result.files.count) \(result.files.count == 1 ? "track" : "tracks") written to")
                    .foregroundStyle(.secondary)
                Text((result.folder.path as NSString).abbreviatingWithTildeInPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            GlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    Button("Reveal in Finder", systemImage: "folder", action: onReveal)
                        .glassButtonStyle(prominent: true)
                    Button("Back to Settings", action: onEdit)
                        .glassButtonStyle()
                }
            }
            .controlSize(.large)

            WarningsList(warnings: result.warnings)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "music.note.list").foregroundStyle(.secondary)
                Text("In Music, choose File ▸ Add to Library… and pick the folder. The tracks appear as one album and play without gaps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .card(radius: 12)
        }
    }
}
