//
//  ScheduleQuizSummaryCard.swift
//  Create_Schedule_Kit
//
//  Schedule Details' quiz section: one line per Pre/Post slot and a Manage button.
//

import SwiftUI

struct ScheduleQuizSummaryCard: View {

    typealias DM = ScheduleQuizDataModel

    let quizzes: DM.ScheduleQuizzes
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(DM.QuizKind.allCases) { kind in
                row(kind: kind, quiz: quizzes.quiz(kind))
                Divider()
            }
            Button(action: onManage) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                    Text("Manage quizzes")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(CSTheme.primaryColor)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    private func row(kind: DM.QuizKind, quiz: DM.QuizSummary?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CSQuizKindBadge(kind: kind)
            VStack(alignment: .leading, spacing: 4) {
                Text(quiz?.title ?? "Not added")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(quiz == nil ? .secondary : .primary)
                if let quiz {
                    Text("\(quiz.totalQuestions.questionsLabel) · \(quiz.totalMarks.marksLabel) · pass \(quiz.passText)")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let quiz {
                CSStatusChip(
                    title: quiz.isPublished ? "Published" : "Draft",
                    tint: quiz.isPublished ? .green : .orange
                )
            }
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScheduleQuizSummaryCard(
        quizzes: .init(
            scheduleId: 4826,
            preQuiz: .init(id: 97, quizTypeId: 1, title: "class56 — pre check", totalQuestions: 2, totalMarks: 2,
                           passPercentage: 60, durationMinutes: nil, showResultToLearner: true,
                           isPublished: true, publishedOn: nil, isLocked: false, attemptCount: 0),
            postQuiz: nil
        ),
        onManage: {}
    )
    .padding()
    .background(Color.scheduleBackground)
}
