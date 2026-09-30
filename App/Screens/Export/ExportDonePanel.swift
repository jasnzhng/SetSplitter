//
//  ExportDonePanel.swift
//  SetSplitter
//
//  Success state, staged as an album on a table: the cover as a sleeve, with the
//  record sliding out from behind it. Beside it: where the album went, how to add it
//  to Music, and anything the planner had to drop along the way.
//

import SwiftUI
import SetSplitterCore

struct ExportDonePanel: View {

    let result: ExportResult
    let cover: NSImage?
    let palette: ArtPalette
    let onReveal: () -> Void
    let onEdit: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 48) {
            sleeveAndRecord
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
            .frame(maxWidth: 380, alignment: .leading)
        }
        .padding(Theme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if reduceMotion { appeared = true } else {
                withAnimation(.spring(duration: 0.9, bounce: 0.28).delay(0.25)) { appeared = true }
            }
        }
    }

    /// The cover as a sleeve, the record easing out from behind it and beginning to spin.
    private var sleeveAndRecord: some View {
        ZStack(alignment: .leading) {
            VinylRecord(size: 216, isSpinning: appeared, labelColors: Array(palette.colors.prefix(2)), labelImage: cover)
                .offset(x: appeared ? 104 : 8)
            sleeve
        }
        .frame(width: 216 + 112, height: 224, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cover == nil ? "Album, no cover art" : "Album cover")
    }

    @ViewBuilder
    private var sleeve: some View {
        if let cover {
            Image(nsImage: cover)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 216, height: 216)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .frame(width: 216, height: 216)
                .glassSurface(cornerRadius: 10)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        }
    }
}
