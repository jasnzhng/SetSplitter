//
//  StepIndicator.swift
//  SetSplitter
//
//  Header progress for the three-step wizard: one Liquid Glass capsule per step,
//  the current one tinted with the accent. Glass capsules in a group morph into
//  each other as the step changes. Completed steps show a check and are
//  clickable to go back.
//

import SwiftUI

struct StepIndicator: View {

    let current: AppFlow.Step
    let canJump: (AppFlow.Step) -> Bool
    let onSelect: (AppFlow.Step) -> Void

    @Namespace private var pill

    var body: some View {
        GlassGroup(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(AppFlow.Step.allCases) { step in
                    item(step)
                }
            }
        }
        .animation(Theme.smooth, value: current)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Progress")
    }

    private func item(_ step: AppFlow.Step) -> some View {
        let isCurrent = step == current
        let isDone = step < current
        return Button {
            onSelect(step)
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("\(step.rawValue + 1)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                }
                .frame(width: 15, height: 15)
                .background(Circle().fill(isCurrent ? Color.white.opacity(0.28) : Color.secondary.opacity(0.16)))

                Text(step.title)
                    .font(.system(size: 12, weight: isCurrent ? .semibold : .medium))
            }
            .foregroundStyle(isCurrent ? Color.white : (isDone ? Color.primary : Color.secondary))
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .glassCapsule(tint: isCurrent ? Color.accentColor : nil, interactive: !isCurrent && canJump(step))
            .glassEffectID(step.id, in: pill)   // neighbouring capsules morph into each other
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canJump(step) || isCurrent)
        .accessibilityLabel("Step \(step.rawValue + 1), \(step.title)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
