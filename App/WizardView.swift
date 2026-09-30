//
//  WizardView.swift
//  SetSplitter
//
//  The window's content: header with the step indicator, a horizontal pager
//  holding the three screens, and a footer with Back / primary actions.
//

import SwiftUI

struct WizardView: View {

    let model: AppModel

    private var store: SessionStore { model.store }
    private var actions: WizardActions { WizardActions(model: model) }

    var body: some View {
        VStack(spacing: 0) {
            header
            pager
            footer
        }
        .frame(minWidth: 900, minHeight: 640)
        .background { LivingBackdrop(palette: store.backdropPalette) }
        .environment(store)
    }

    // MARK: Header

    private var header: some View {
        StepIndicator(
            current: store.step,
            canJump: { $0 < store.step && !store.exportState.isRunning },
            onSelect: { store.go(to: $0) })
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(alignment: .bottom) { Divider().opacity(0.6) }
    }

    // MARK: Pager

    /// Screens sit side by side and slide, rather than being inserted and
    /// removed. That keeps each screen's state alive and makes "back" the exact
    /// reverse of "forward" without direction-dependent transitions.
    private var pager: some View {
        GeometryReader { geo in
            ZStack {
                page(.importFile, width: geo.size.width) { ImportScreen(model: model.importViewModel) }
                page(.tracklist, width: geo.size.width) { TracklistScreen(model: model.tracklistViewModel) }
                page(.export, width: geo.size.width) { ExportScreen(model: model.exportViewModel) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private func page<Content: View>(_ step: AppFlow.Step, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        let isCurrent = store.step == step
        return content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A full page-width apart, so off-screen pages sit entirely outside the window: AppKit
            // routes drags by view frame, and a parallax overlap would let an invisible page's
            // NSTextView swallow file drops meant for the visible one.
            .offset(x: CGFloat(step.rawValue - store.step.rawValue) * width)
            .opacity(isCurrent ? 1 : 0)
            .blur(radius: isCurrent ? 0 : 6)
            .allowsHitTesting(isCurrent)
            // `allowsHitTesting` doesn't stop AppKit-backed views: an off-screen TextEditor's
            // NSTextView would still claim file drops meant for the visible page.
            .disabled(!isCurrent)
            .accessibilityHidden(!isCurrent)
            .animation(Theme.smooth, value: store.step)
    }

    // MARK: Footer

    private var footer: some View {
        // ⌘[ and ⌘⏎ are declared once, on the menu items in `WizardCommands`.
        HStack {
            if actions.canGoBack {
                Button(action: actions.back) {
                    Label("Back", systemImage: "chevron.left")
                }
                .glassButtonStyle()
                .transition(.opacity)
            }
            Spacer()
            if actions.showsPrimary {
                Button(action: actions.primary) {
                    Text(actions.primaryTitle).frame(minWidth: 84)
                }
                .glassButtonStyle(prominent: true)
                .disabled(!actions.primaryEnabled)
                .transition(.opacity)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, Theme.pagePadding)
        .frame(height: 60)
        .background(alignment: .top) { Divider().opacity(0.6) }
        .animation(Theme.quick, value: actions.canGoBack)
    }
}
