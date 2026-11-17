//
//  QuizSlotCardView.swift
//  Create_Schedule_Kit
//
//  One Pre/Post slot: badge + name, then either the quiz summary with Edit / Delete, or a
//  one-line explainer + Create while the slot is empty.
//

import SwiftUI

struct QuizSlotCardView: View {

    let kind: ScheduleQuizDataModel.QuizKind
    let quiz: ScheduleQuizDataModel.QuizSummary?
    let isActionEnabled: Bool
    let emptyText: String
    let onCreate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let quiz {
                Divider()
                summary(quiz)
            } else {
                emptyState
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(quiz != nil ? CSTheme.primaryColor.opacity(0.04) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(quiz != nil ? CSTheme.primaryColor.opacity(0.35) : Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private var header: some View {
        HStack(spacing: 10) {
            CSQuizKindBadge(kind: kind)
            Text(kind.slotTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
            Spacer(minLength: 4)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(emptyText)
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            capsuleButton(title: "Create \(kind.lowercasedTitle)", systemImage: "plus", action: onCreate)
                .disabled(!isActionEnabled)
                .opacity(isActionEnabled ? 1 : 0.5)
        }
    }

    private func summary(_ quiz: ScheduleQuizDataModel.QuizSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(quiz.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if quiz.isPublished {
                        CSStatusChip(title: "Published", tint: .green)
                    } else {
                        CSStatusChip(title: "Draft", tint: .orange)
                    }
                    if quiz.isLocked {
                        CSStatusChip(title: "Locked", systemImage: "lock.fill", tint: .gray)
                    }
                    if quiz.attemptCount > 0 {
                        Text(quiz.attemptCount == 1 ? "1 attempt" : "\(quiz.attemptCount) attempts")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(alignment: .top) {
                stat("Questions", "\(quiz.totalQuestions)")
                stat("Total marks", quiz.totalMarks.marksText)
                stat("Pass", quiz.passText)
                stat("Duration", quiz.durationText)
            }

            if !quiz.isPublished, quiz.totalQuestions == 0 {
                Text("Add questions and save to publish it to learners.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.orange)
            }

            HStack(spacing: 12) {
                capsuleButton(title: quiz.isLocked ? "View questions" : "Edit questions",
                              systemImage: "square.and.pencil", action: onEdit)

                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
                .disabled(!isActionEnabled)
                Spacer(minLength: 0)
            }
        }
    }

    private func capsuleButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CSTheme.primaryColor.getDynamicTextColor)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Capsule().fill(CSTheme.primaryColor))
        }
        .buttonStyle(.plain)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 14) {
        QuizSlotCardView(
            kind: .pre,
            quiz: .init(id: 97, quizTypeId: 1, title: "class56 — pre check", totalQuestions: 2, totalMarks: 2,
                        passPercentage: nil, durationMinutes: nil, showResultToLearner: true,
                        isPublished: true, publishedOn: "29-10-2026", isLocked: true, attemptCount: 1),
            isActionEnabled: true,
            emptyText: "", onCreate: {}, onEdit: {}, onDelete: {}
        )
        QuizSlotCardView(
            kind: .post, quiz: nil, isActionEnabled: true,
            emptyText: "Learners take it after the session. Create it now and add questions in the editor.",
            onCreate: {}, onEdit: {}, onDelete: {}
        )
    }
    .padding()
    .background(Color.scheduleBackground)
}
