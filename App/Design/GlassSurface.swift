//
//  GlassSurface.swift
//  SetSplitter
//
//  Liquid Glass helpers. Glass is native on macOS 26, the app's minimum, so these are thin
//  wrappers that keep call sites short. The only fallback left is for the DEBUG snapshot harness
//  (see `GlassSupport`).
//

import SwiftUI

/// Debug builds can switch Liquid Glass off with the `--no-glass` launch argument. The snapshot
/// harness uses this: it renders views offscreen, where glass (a compositor effect) can't be drawn,
/// so it reviews layout against a material stand-in instead. Release builds always use glass.
enum GlassSupport {
    #if DEBUG
    static let isEnabled = !CommandLine.arguments.contains("--no-glass")
    #else
    static let isEnabled = true
    #endif
}

extension View {

    /// A Liquid Glass panel in a continuous rounded rectangle.
    /// - Parameters:
    ///   - tint: Colours the glass, e.g. the accent for a selected element.
    ///   - interactive: Makes the glass react to press and pointer, for tappable surfaces.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = Theme.cardRadius, tint: Color? = nil, interactive: Bool = false) -> some View {
        if GlassSupport.isEnabled {
            self.glassEffect(Self.glass(tint: tint, interactive: interactive),
                             in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
        }
    }

    /// A Liquid Glass capsule.
    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        if GlassSupport.isEnabled {
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
        if GlassSupport.isEnabled {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }

    private static func glass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

/// Groups nearby glass elements so they blend and morph together.
struct GlassGroup<Content: View>: View {

    var spacing: CGFloat = 8
    @ViewBuilder let content: Content

    var body: some View {
        if GlassSupport.isEnabled {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
