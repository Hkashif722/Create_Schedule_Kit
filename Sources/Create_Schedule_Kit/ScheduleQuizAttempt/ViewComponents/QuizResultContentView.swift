//
//  QuizResultContentView.swift
//  Create_Schedule_Kit
//
//  Result body shared by the player (right after Submit) and "View result": outcome banner,
//  score tiles, score bar, answer review, Done. Hidden results get the banner only.
//

import SwiftUI

struct QuizResultContentView: View {

    typealias DM = ScheduleQuizAttemptDataModel

    let result: DM.AttemptResult
    let onDone: () -> Void

    private var outcome: DM.ResultOutcome { result.outcome }

    private var tint: Color {
        switch outcome {
        case .passed:  return .green
        case .failed:  return .red
        case .neutral, .hidden: return CSTheme.primaryColor
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    outcomeBanner
                    if outcome != .hidden, let score = result.score {
                        scoreTiles(score)
                        VStack(alignment: .leading, spacing: 18) {
                            QuizScoreBarView(
                                percentage: score.percentage,
                                passPercentage: result.passPercentage,
                                tint: tint
                            )
                            metaLine
                            review
                        }
                        .padding(16)
                    }
                }
            }
            CSPrimaryButton(title: "Done", action: onDone)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        }
    }
}

// MARK: - Sub-views
private extension QuizResultContentView {

    var bannerCopy: (icon: String, title: String, subtitle: String) {
        switch outcome {
        case .passed:
            return ("checkmark", "Congratulations! You Passed", "Your response has been recorded successfully.")
        case .failed:
            return ("xmark", "Quiz Not Passed", "Don't worry, your response has been recorded.")
        case .neutral:
            return ("checkmark", "Quiz submitted", "Your response has been recorded successfully.")
        case .hidden:
            return ("checkmark", "Quiz submitted", "Your response has been recorded. Results aren't shared for this quiz.")
        }
    }

    var outcomeBanner: some View {
        let copy = bannerCopy
        return VStack(spacing: 10) {
            Circle()
                .strokeBorder(tint, lineWidth: 3)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: copy.icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(tint)
                )
                .accessibilityHidden(true)
            Text(copy.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(outcome == .hidden || outcome == .neutral ? .primary : tint)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(copy.subtitle)
                .font(.system(size: 13.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background(tint.opacity(0.08))
        .accessibilityElement(children: .combine)
    }

    func scoreTiles(_ score: DM.Score) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tile(value: "\(score.obtainedMarks.marksText)/\(score.totalMarks.marksText)", caption: "SCORE", color: .primary)
                Divider()
                tile(value: "\(score.percentage.marksText)%", caption: "PERCENTAGE", color: tint)
                Divider()
                tile(value: "\(score.correctCount)", caption: "CORRECT", color: .green)
                Divider()
                tile(value: "\(score.wrongCount)", caption: "INCORRECT", color: .red)
            }
            .frame(height: 72)
            if score.unansweredCount > 0 {
                Text("\(score.unansweredCount) not answered")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            Divider()
        }
        .background(Color(.systemBackground))
    }

    func tile(value: String, caption: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    var metaLine: some View {
        let parts = [
            result.submittedOn.map { "Submitted on \($0)" },
            result.timeTakenSeconds.map { "Time taken \(DM.Countdown.clockText($0))" }
        ].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    var review: some View {
        if !result.questions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("ANSWER REVIEW")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                ForEach(Array(result.questions.enumerated()), id: \.element.id) { index, question in
                    QuizReviewRowView(number: index + 1, question: question)
                }
            }
        }
    }
}

#Preview {
    typealias DM = ScheduleQuizAttemptDataModel
    let result = DM.AttemptResult(
        attemptId: 1, quizId: 2, title: "class56 — pre check", submittedOn: "29-10-2026",
        timeTakenSeconds: 245, passPercentage: 60, resultVisible: true,
        score: .init(totalMarks: 10, obtainedMarks: 6, percentage: 60, isPassed: true,
                     correctCount: 3, wrongCount: 2, unansweredCount: 0),
        questions: [
            .init(attemptQuestionId: 1, sortOrder: 1, questionText: "What does LCMS stand for in a learning context?",
                  marksAllotted: 2, marksObtained: 2, isAnswered: true, isCorrect: true,
                  options: [.init(id: 1, optionText: "Learning Content Management System", isCorrect: true, isSelected: true)]),
            .init(attemptQuestionId: 2, sortOrder: 2, questionText: "Who can display the QR code?",
                  marksAllotted: 2, marksObtained: 0, isAnswered: true, isCorrect: false,
                  options: [.init(id: 2, optionText: "Module director", isCorrect: false, isSelected: true),
                            .init(id: 3, optionText: "Trainer", isCorrect: true, isSelected: false)])
        ]
    )
    return QuizResultContentView(result: result, onDone: {})
        .background(Color.scheduleBackground)
}
