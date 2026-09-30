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
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(store)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            StepIndicator(
                current: store.step,
                canJump: { $0 < store.step && !store.exportState.isRunning },
                onSelect: { step in withAnimation(Theme.spring) { store.go(to: step) } })
        }
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
            .offset(x: CGFloat(step.rawValue - store.step.rawValue) * width * 0.35)
            .opacity(isCurrent ? 1 : 0)
            .blur(radius: isCurrent ? 0 : 6)
            .allowsHitTesting(isCurrent)
            .accessibilityHidden(!isCurrent)
            .animation(Theme.spring, value: store.step)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if actions.canGoBack {
                Button {
                    withAnimation(Theme.spring) { actions.back() }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .keyboardShortcut("[")
                .transition(.opacity)
            }
            Spacer()
            if actions.showsPrimary {
                Button {
                    withAnimation(Theme.spring) { actions.primary() }
                } label: {
                    Text(actions.primaryTitle).frame(minWidth: 84)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
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
