//
//  CSStepTracker.swift
//  Create_Schedule_Kit
//
//  Circular numbered step tracker for the wizard header (Basics / Venue / Feedback /
//  Nominate). Completed steps show a check, the current step is filled with a halo,
//  and upcoming steps use a dashed outline. Connector lines fill up to the current step.
//

import SwiftUI
import SwiftUIUtilities

struct CSStepTracker: View {

    let steps: [String]
    let currentStep: Int   // 1-based

    private let circleSize: CGFloat = 34

    private enum StepState { case completed, current, upcoming }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                let n = index + 1
                VStack(spacing: 8) {
                    ZStack {
                        HStack(spacing: 0) {
                            connector(visible: index > 0, filled: n <= currentStep)
                            connector(visible: index < steps.count - 1, filled: n < currentStep)
                        }
                        circle(n)
                    }
                    Text(label)
                        .font(.system(size: 12.5, weight: state(n) == .upcoming ? .medium : .semibold))
                        .foregroundColor(labelColor(n))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Pieces

    private func connector(visible: Bool, filled: Bool) -> some View {
        Rectangle()
            .fill(visible ? (filled ? ColorUtility.primaryColor : Color(.systemGray4)) : Color.clear)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func circle(_ n: Int) -> some View {
        ZStack {
            switch state(n) {
            case .completed:
                Circle().fill(ColorUtility.primaryColor)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(ColorUtility.primaryColor.getDynamicTextColor)
            case .current:
                Circle().fill(ColorUtility.primaryColor)
                Text("\(n)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorUtility.primaryColor.getDynamicTextColor)
            case .upcoming:
                Circle().fill(Color(.systemBackground))
                Circle()
                    .strokeBorder(ColorUtility.primaryColor.opacity(0.6),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Text("\(n)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorUtility.primaryColor)
            }
        }
        .frame(width: circleSize, height: circleSize)
        .background {
            if state(n) == .current {
                Circle()
                    .fill(ColorUtility.primaryColor.opacity(0.15))
                    .frame(width: circleSize + 9, height: circleSize + 9)
            }
        }
    }

    // MARK: - State helpers

    private func state(_ n: Int) -> StepState {
        if n < currentStep { return .completed }
        if n == currentStep { return .current }
        return .upcoming
    }

    private func labelColor(_ n: Int) -> Color {
        switch state(n) {
        case .completed: return ColorUtility.deepGreen
        case .current:   return ColorUtility.primaryColor
        case .upcoming:  return .secondary
        }
    }
}
