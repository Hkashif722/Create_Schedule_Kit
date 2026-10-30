//
//  QuizScoreBarView.swift
//  Create_Schedule_Kit
//
//  Score bar on the result screen, with a tick at the pass mark when the quiz has one.
//

import SwiftUI

struct QuizScoreBarView: View {
    /// 0–100.
    let percentage: Double
    /// 0–100, nil = no pass mark.
    let passPercentage: Double?
    let tint: Color

    private func fraction(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0), 100) / 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Your score")
                Spacer()
                if let passPercentage {
                    Text("Passing score: \(passPercentage.marksText)%")
                }
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 10)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, width * fraction(percentage)), height: 10)
                    if let passPercentage {
                        Rectangle()
                            .fill(Color.primary.opacity(0.55))
                            .frame(width: 2, height: 16)
                            .offset(x: width * fraction(passPercentage) - 1, y: -3)
                        Text("\(passPercentage.marksText)% ↑")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .fixedSize()
                            .frame(width: 60, alignment: .center)
                            .offset(x: min(max(width * fraction(passPercentage) - 30, 0), width - 60), y: 16)
                    }
                }
            }
            .frame(height: passPercentage == nil ? 10 : 32)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your score \(percentage.marksText) percent"
                            + (passPercentage.map { ", passing score \($0.marksText) percent" } ?? ""))
    }
}

#Preview {
    VStack(spacing: 24) {
        QuizScoreBarView(percentage: 60, passPercentage: 60, tint: .green)
        QuizScoreBarView(percentage: 0, passPercentage: 60, tint: .red)
        QuizScoreBarView(percentage: 75, passPercentage: nil, tint: .blue)
    }
    .padding()
}
