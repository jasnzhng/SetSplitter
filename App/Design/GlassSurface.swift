//
//  GlassSurface.swift
//  SetSplitter
//
//  Liquid Glass, gated. The Glass APIs are macOS 26+, but the app supports
//  macOS 14, so every use goes through these helpers: on 26+ they produce real
//  Liquid Glass (which refracts the living backdrop behind it), and on earlier
//  systems they fall back to the equivalent material / bordered button.
//

import SwiftUI

/// Liquid Glass can be switched off with the `--no-glass` launch argument. The DEBUG snapshot
/// harness uses this: it renders views offscreen, where glass (a compositor effect) can't be drawn,
/// so it reviews layout against the material fallback instead.
enum GlassSupport {
    static let isEnabled = !CommandLine.arguments.contains("--no-glass")
}

extension View {

    /// A Liquid Glass panel in a continuous rounded rectangle (material fallback before macOS 26).
    /// - Parameters:
    ///   - tint: Colours the glass, e.g. the accent for a selected element.
    ///   - interactive: Makes the glass react to press and pointer, for tappable surfaces.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = Theme.cardRadius, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *), GlassSupport.isEnabled {
            self.glassEffect(Self.glass(tint: tint, interactive: interactive),
                             in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
        }
    }

    /// A Liquid Glass capsule (material fallback before macOS 26).
    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *), GlassSupport.isEnabled {
            self.glassEffect(Self.glass(tint: tint, interactive: interactive), in: Capsule())
        } else if let tint {
            self.background(tint, in: Capsule())   // no glass to tint: fill with the colour instead
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }

    /// Glass button style: `.glassProminent` for the primary action, `.glass` otherwise.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *), GlassSupport.isEnabled {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }

    @available(macOS 26.0, *)
    private static func glass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

/// Groups nearby glass elements so they blend and morph together (a plain container before macOS 26).
struct GlassGroup<Content: View>: View {

    var spacing: CGFloat = 8
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *), GlassSupport.isEnabled {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
