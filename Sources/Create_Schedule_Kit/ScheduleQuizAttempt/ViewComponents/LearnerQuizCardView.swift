//
//  LearnerQuizCardView.swift
//  Create_Schedule_Kit
//
//  One Pre or Post quiz card on the learner's schedule quiz screen: what the quiz is, and the
//  one thing the learner can do with it right now.
//

import SwiftUI

struct LearnerQuizCardView: View {

    typealias DM = ScheduleQuizAttemptDataModel

    let slot: LearnerQuizSlot
    let onStart: () -> Void
    let onResume: () -> Void
    let onViewResult: () -> Void

    private var card: DM.QuizCard { slot.card }
    private var status: DM.CardStatus { card.status }

    private var isIneligible: Bool {
        if case .ineligible = status { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            titleBlock
            stats
            Divider()
            statusSection
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }
}

// MARK: - Sub-views
private extension LearnerQuizCardView {

    var headerRow: some View {
        HStack(spacing: 8) {
            CSQuizKindBadge(kind: slot.kind)
            Text(slot.kind.slotTitle.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            statusChip
        }
    }

    @ViewBuilder
    var statusChip: some View {
        switch status {
        case .ineligible:
            CSStatusChip(title: "Not available", systemImage: "lock.fill", tint: .gray)
        case .notStarted:
            CSStatusChip(title: "Not started", tint: .blue)
        case .inProgress:
            CSStatusChip(title: "In progress", systemImage: "clock", tint: .orange)
        case .submitted:
            CSStatusChip(title: "Submitted", systemImage: "checkmark", tint: .green)
        }
    }

    var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title.isEmpty ? slot.kind.slotTitle : card.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let instructions = card.instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
               !instructions.isEmpty {
                Text(instructions)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(isIneligible ? 0.6 : 1)
    }

    var stats: some View {
        HStack(alignment: .top, spacing: 8) {
            stat(title: "Questions", value: "\(card.totalQuestions)")
            stat(title: "Marks", value: card.totalMarks.marksText)
            stat(title: "Pass", value: card.passText)
            stat(title: "Duration", value: card.durationText)
        }
        .opacity(isIneligible ? 0.6 : 1)
    }

    func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    var statusSection: some View {
        switch status {
        case .ineligible(let reason):
            CSInfoBanner(style: .warning, message: reason, systemImage: "lock.fill")

        case .notStarted:
            CSPrimaryButton(title: "Start quiz", systemImage: "play.fill", action: onStart)

        case .inProgress(let remaining):
            VStack(spacing: 10) {
                if let remaining {
                    Label("\(DM.Countdown.clockText(remaining)) left", systemImage: "clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                CSPrimaryButton(title: "Resume quiz", systemImage: "play.fill", action: onResume)
            }

        case .submitted(let score):
            if let score {
                VStack(spacing: 12) {
                    scoreSummary(score)
                    CSSecondaryButton(title: "View result", systemImage: "doc.text.magnifyingglass", action: onViewResult)
                }
            } else {
                CSInfoBanner(style: .success, title: "Submitted", message: "Your response has been recorded.")
            }
        }
    }

    func scoreSummary(_ score: DM.Score) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your score")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(score.obtainedMarks.marksText)/\(score.totalMarks.marksText) · \(score.percentage.marksText)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
            }
            Spacer(minLength: 8)
            if let isPassed = score.isPassed {
                CSStatusChip(
                    title: isPassed ? "Passed" : "Not passed",
                    systemImage: isPassed ? "checkmark.seal.fill" : "xmark.seal.fill",
                    tint: isPassed ? .green : .red
                )
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    func card(state: ScheduleQuizAttemptDataModel.AttemptState, eligible: Bool = true,
              score: ScheduleQuizAttemptDataModel.Score? = nil) -> ScheduleQuizAttemptDataModel.QuizCard {
        .init(quizId: 1, quizTypeId: 1, title: "class56 — pre check",
              instructions: "Answer every question before the session starts.",
              totalQuestions: 5, totalMarks: 10, passPercentage: 60, durationMinutes: 15,
              isEligible: eligible, ineligibleReason: eligible ? nil : "You need to be registered for this schedule.",
              state: state, attemptId: 9, attemptsRemaining: 1, remainingSeconds: state == .inProgress ? 545 : nil,
              score: score)
    }
    let score = ScheduleQuizAttemptDataModel.Score(
        totalMarks: 10, obtainedMarks: 6, percentage: 60, isPassed: true,
        correctCount: 3, wrongCount: 2, unansweredCount: 0
    )
    return ScrollView {
        VStack(spacing: 16) {
            LearnerQuizCardView(slot: .init(kind: .pre, card: card(state: .notStarted)),
                                onStart: {}, onResume: {}, onViewResult: {})
            LearnerQuizCardView(slot: .init(kind: .post, card: card(state: .inProgress)),
                                onStart: {}, onResume: {}, onViewResult: {})
            LearnerQuizCardView(slot: .init(kind: .pre, card: card(state: .submitted, score: score)),
                                onStart: {}, onResume: {}, onViewResult: {})
            LearnerQuizCardView(slot: .init(kind: .post, card: card(state: .notStarted, eligible: false)),
                                onStart: {}, onResume: {}, onViewResult: {})
        }
        .padding()
    }
    .background(Color.scheduleBackground)
}
