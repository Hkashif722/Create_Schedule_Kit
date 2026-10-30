//
//  QuizQuestionPaletteView.swift
//  Create_Schedule_Kit
//
//  Numbered question jump strip. Current = filled, answered = green tint.
//

import SwiftUI

struct QuizQuestionPaletteView: View {

    /// `attemptQuestionId`s in display order.
    let questionIDs: [Int]
    let currentIndex: Int
    let answeredIDs: Set<Int>
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(questionIDs.enumerated()), id: \.element) { index, questionID in
                        cell(index: index, questionID: questionID)
                            .id(questionID)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                // resume can open mid-quiz, and onChange skips the first value
                guard questionIDs.indices.contains(currentIndex) else { return }
                let target = questionIDs[currentIndex]
                Task { @MainActor in proxy.scrollTo(target, anchor: .center) }
            }
            .onChange(of: currentIndex) { index in
                guard questionIDs.indices.contains(index) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(questionIDs[index], anchor: .center)
                }
            }
        }
    }

    private func cell(index: Int, questionID: Int) -> some View {
        let isCurrent = index == currentIndex
        let isAnswered = answeredIDs.contains(questionID)
        return Button { onSelect(index) } label: {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isCurrent ? CSTheme.primaryColor.getDynamicTextColor : (isAnswered ? .green : .primary))
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isCurrent ? CSTheme.primaryColor : (isAnswered ? Color.green.opacity(0.12) : Color(.systemBackground)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isCurrent ? Color.clear : (isAnswered ? Color.green.opacity(0.6) : Color(.systemGray4)), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Question \(index + 1)")
        .accessibilityValue(isAnswered ? "Answered" : "Not answered")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

#Preview {
    QuizQuestionPaletteView(
        questionIDs: [11, 12, 13, 14, 15],
        currentIndex: 1,
        answeredIDs: [11],
        onSelect: { _ in }
    )
    .padding()
}
