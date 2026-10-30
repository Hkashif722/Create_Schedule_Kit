//
//  LiveQuizRowView.swift
//  Create_Schedule_Kit
//
//  One Pre or Post row under "Live Quiz" on the learner's schedule card: status tile, what the
//  learner can do next (or why it's locked), and the score once submitted.
//

import SwiftUI

struct LiveQuizRowView: View {

    typealias DM = ScheduleQuizAttemptDataModel

    let slot: LearnerQuizSlot
    let onTap: () -> Void

    private var status: DM.CardStatus { slot.card.status }

    private var isLocked: Bool {
        if case .ineligible = status { return true }
        return false
    }

    var body: some View {
        if isLocked {
            rowContent
                .accessibilityElement(children: .combine)
        } else {
            Button(action: onTap) { rowContent }
                .buttonStyle(.plain)
        }
    }
}

// MARK: - Sub-views
private extension LiveQuizRowView {

    var rowContent: some View {
        HStack(spacing: 14) {
            statusTile
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.kind.learnerTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let scoreText {
                Text(scoreText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background { Capsule().fill(Color.blue.opacity(0.12)) }
                    .fixedSize()
            }
            if !isLocked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isLocked ? Color(.systemGray6) : Color(.systemBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(.systemGray4), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    var statusTile: some View {
        Image(systemName: tile.icon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tile.tint)
            .frame(width: 46, height: 46)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tile.tint.opacity(0.12))
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Helpers
private extension LiveQuizRowView {

    var tile: (icon: String, tint: Color) {
        switch status {
        case .ineligible: return ("lock.fill", .gray)
        case .notStarted: return ("clock.fill", CSTheme.primaryColor)
        case .inProgress: return ("play.circle.fill", .orange)
        case .submitted:  return ("checkmark.circle.fill", .green)
        }
    }

    var subtitle: String {
        switch status {
        case .ineligible(let reason):
            return reason
        case .notStarted:
            return "Start quiz"
        case .inProgress(let remaining):
            guard let remaining else { return "Resume quiz" }
            return "Resume quiz · \(DM.Countdown.clockText(remaining)) left"
        case .submitted:
            return "View result"
        }
    }

    var scoreText: String? {
        guard case .submitted(let score?) = status else { return nil }
        return "\(score.percentage.marksText)%"
    }
}

#Preview {
    func card(state: ScheduleQuizAttemptDataModel.AttemptState, eligible: Bool = true, reason: String? = nil,
              score: ScheduleQuizAttemptDataModel.Score? = nil) -> ScheduleQuizAttemptDataModel.QuizCard {
        .init(quizId: 1, quizTypeId: 1, title: "class56 — pre check", instructions: nil,
              totalQuestions: 5, totalMarks: 10, passPercentage: 60, durationMinutes: 15,
              isEligible: eligible, ineligibleReason: reason,
              state: state, attemptId: 9, attemptsRemaining: eligible ? 1 : 0,
              remainingSeconds: state == .inProgress ? 545 : nil, score: score)
    }
    let score = ScheduleQuizAttemptDataModel.Score(
        totalMarks: 2, obtainedMarks: 2, percentage: 100, isPassed: nil,
        correctCount: 2, wrongCount: 0, unansweredCount: 0
    )
    return VStack(spacing: 10) {
        LiveQuizRowView(slot: .init(kind: .pre, card: card(state: .submitted, eligible: false,
                                                            reason: "You have already taken this quiz.",
                                                            score: score)), onTap: {})
        LiveQuizRowView(slot: .init(kind: .post, card: card(state: .notStarted, eligible: false,
                                                             reason: "The post quiz opens once your attendance for this schedule is marked completed.")),
                        onTap: {})
        LiveQuizRowView(slot: .init(kind: .pre, card: card(state: .notStarted)), onTap: {})
        LiveQuizRowView(slot: .init(kind: .post, card: card(state: .inProgress)), onTap: {})
    }
    .padding()
}
