//
//  QuizReviewRowView.swift
//  Create_Schedule_Kit
//
//  One row of ANSWER REVIEW: right/wrong, the question, marks earned, the learner's answer and
//  (when wrong) the correct one.
//

import SwiftUI

struct QuizReviewRowView: View {
    let number: Int
    let question: ScheduleQuizAttemptDataModel.ResultQuestion

    private var tint: Color {
        if !question.isAnswered { return .gray }
        return question.isCorrect ? .green : .red
    }

    private var icon: String {
        if !question.isAnswered { return "minus.circle.fill" }
        return question.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var marksText: String {
        let earned = question.marksObtained.marksText
        let total = question.marksAllotted.marksText
        return question.marksObtained > 0 ? "+\(earned)/\(total)" : "\(earned)/\(total)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(tint)
                    .accessibilityHidden(true)
                Text("Q\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.top, 1)
                Text(question.questionText)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(marksText)
                    .font(.system(size: 13, weight: .bold))
                    .fixedSize()
                    .foregroundColor(question.marksObtained > 0 ? .green : .red)
            }
            .padding(12)
            .background(tint.opacity(0.07))

            VStack(alignment: .leading, spacing: 6) {
                answerLine(
                    label: "Your answer:",
                    value: question.selectedText ?? "Not answered",
                    color: question.selectedText == nil ? .secondary : (question.isCorrect ? .green : .red)
                )
                if !question.isCorrect, !question.correctText.isEmpty {
                    answerLine(label: "Correct:", value: question.correctText, color: .green)
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func answerLine(label: String, value: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    typealias DM = ScheduleQuizAttemptDataModel
    let wrong = DM.ResultQuestion(
        attemptQuestionId: 1, sortOrder: 1, questionText: "Who can display the QR code for participants?",
        marksAllotted: 2, marksObtained: 0, isAnswered: true, isCorrect: false,
        options: [
            .init(id: 1, optionText: "Module director", isCorrect: false, isSelected: true),
            .init(id: 2, optionText: "Trainer", isCorrect: true, isSelected: false)
        ]
    )
    let right = DM.ResultQuestion(
        attemptQuestionId: 2, sortOrder: 2, questionText: "What does LCMS stand for?",
        marksAllotted: 2, marksObtained: 2, isAnswered: true, isCorrect: true,
        options: [.init(id: 3, optionText: "Learning Content Management System", isCorrect: true, isSelected: true)]
    )
    return VStack(spacing: 12) {
        QuizReviewRowView(number: 1, question: right)
        QuizReviewRowView(number: 2, question: wrong)
    }
    .padding()
}
