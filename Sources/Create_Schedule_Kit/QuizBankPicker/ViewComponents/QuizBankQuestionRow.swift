//
//  QuizBankQuestionRow.swift
//  Create_Schedule_Kit
//

import SwiftUI

struct QuizBankQuestionRow: View {

    let question: ScheduleQuizDataModel.BankQuestion
    let isSelected: Bool
    let isBlocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                QuizCheckbox(isOn: isSelected, isEnabled: !isBlocked)
                VStack(alignment: .leading, spacing: 6) {
                    Text(question.questionText ?? "Untitled question")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isBlocked ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    metaRow
                    if isBlocked {
                        CSStatusChip(title: "Already in quiz", tint: .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected && !isBlocked ? CSTheme.primaryColor.opacity(0.06) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected && !isBlocked ? CSTheme.primaryColor : Color(.systemGray4), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBlocked)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            chip(ScheduleQuizDataModel.OptionType(apiValue: question.optionType).shortTitle)
            if let difficulty = question.difficultyLevel, !difficulty.isEmpty {
                chip(difficulty)
            }
            Text("\(question.optionsCount) options · \(question.marks.marksLabel)")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundColor(.primary.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(.systemGray6)))
    }
}

#Preview {
    VStack(spacing: 10) {
        QuizBankQuestionRow(
            question: .init(id: 1, questionText: "Where is the assembly point?", optionType: "SingleSelection",
                            section: "objective", difficultyLevel: "Simple", marks: 1, optionsCount: 4,
                            alreadyAdded: false),
            isSelected: true, isBlocked: false, onTap: {}
        )
        QuizBankQuestionRow(
            question: .init(id: 2, questionText: "Which class of fire involves flammable liquids?",
                            optionType: "MultipleSelection", section: nil, difficultyLevel: "Difficult",
                            marks: 2, optionsCount: 5, alreadyAdded: true),
            isSelected: true, isBlocked: true, onTap: {}
        )
    }
    .padding()
}
