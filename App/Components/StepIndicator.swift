//
//  StepIndicator.swift
//  SetSplitter
//
//  Header progress for the three-step wizard: a capsule track with a single
//  accent pill that slides between steps. Completed steps show a check and
//  are clickable to go back.
//

import SwiftUI

struct StepIndicator: View {

    let current: AppFlow.Step
    let canJump: (AppFlow.Step) -> Bool
    let onSelect: (AppFlow.Step) -> Void

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppFlow.Step.allCases) { step in
                item(step)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color(nsColor: .quaternarySystemFill)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Progress")
    }

    private func item(_ step: AppFlow.Step) -> some View {
        let isCurrent = step == current
        let isDone = step < current
        return Button {
            onSelect(step)
        } label: {
            HStack(spacing: 5) {
                ZStack {
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("\(step.rawValue + 1)")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    }
                }
                .frame(width: 15, height: 15)
                .background(Circle().fill(isCurrent ? Color.white.opacity(0.28) : Color.secondary.opacity(0.16)))

                Text(step.title)
                    .font(.system(size: 12, weight: isCurrent ? .semibold : .medium))
            }
            .foregroundStyle(isCurrent ? Color.white : (isDone ? Color.primary : Color.secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background {
                if isCurrent {
                    Capsule().fill(Color.accentColor)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canJump(step) || isCurrent)
        .accessibilityLabel("Step \(step.rawValue + 1), \(step.title)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
