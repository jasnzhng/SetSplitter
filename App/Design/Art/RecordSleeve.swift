//
//  RecordSleeve.swift
//  SetSplitter
//
//  The album cover dressed as a real record sleeve: slightly rounded corners, a
//  diagonal sheen and a soft specular highlight from the top-left, a faint
//  ring-wear circle where a record has lived, a darkened lip along the open left
//  edge (so a record sliding in reads as going *inside*), a lit edge, and a
//  contact shadow. With no cover, a neutral glass sleeve stands in.
//

import SwiftUI

struct RecordSleeve: View {

    let cover: NSImage?
    var size: CGFloat = 268

    private let cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            art
            // Ring wear: the faint imprint of the record inside.
            Circle()
                .strokeBorder(.white.opacity(0.12), lineWidth: size * 0.006)
                .padding(size * 0.02)
                .blendMode(.plusLighter)
            // Sheen: light falls from the top-left.
            LinearGradient(
                stops: [.init(color: .white.opacity(0.30), location: 0),
                        .init(color: .white.opacity(0.06), location: 0.35),
                        .init(color: .clear, location: 0.6),
                        .init(color: .black.opacity(0.20), location: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            // Specular highlight.
            RadialGradient(colors: [.white.opacity(0.30), .clear], center: .topLeading, startRadius: 0, endRadius: size * 0.75)
                .blendMode(.softLight)
            // The sleeve's open edge: a shadowed lip on the left.
            HStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.50), .black.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: size * 0.07)
                Spacer(minLength: 0)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            // A lit top/left edge and a shaded bottom/right edge, like a card's bevel.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.05), .black.opacity(0.35)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 2)      // contact
        .shadow(color: .black.opacity(0.35), radius: 26, x: 4, y: 16)    // cast
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var art: some View {
        if let cover {
            Image(nsImage: cover)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(colors: [Color(white: 0.34), Color(white: 0.16)], startPoint: .top, endPoint: .bottom)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.26, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}
