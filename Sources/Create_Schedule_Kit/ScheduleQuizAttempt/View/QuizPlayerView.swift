//
//  QuizPlayerView.swift
//  Create_Schedule_Kit
//
//  Full-screen quiz player: progress + palette, one question at a time, Previous / Next /
//  Submit Quiz, and the result in place once submitted.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct QuizPlayerView: View {

    typealias DM = ScheduleQuizAttemptDataModel

    @StateObject private var viewModel: QuizPlayerViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.LearnerQuizPlayerNavModel) {
        _viewModel = StateObject(
            wrappedValue: QuizPlayerViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            LearnerQuizTopBar(kind: viewModel.navModel.kind, title: viewModel.navModel.title) {
                topBarTrailing
            }
            phaseContent
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension QuizPlayerView {

    @ViewBuilder
    var topBarTrailing: some View {
        if viewModel.phase == .playing {
            HStack(spacing: 8) {
                if let timerText = viewModel.timerText {
                    timerPill(timerText)
                }
                Button { viewModel.didTapExit() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Exit").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color(.systemGray4), lineWidth: 1)
                    )
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSubmitting)
            }
        } else if case .finished = viewModel.phase {
            EmptyView()
        } else {
            SwiftUIUtility.CircleCloseButton(
                foregroundColor: .secondary,
                backgroundColor: Color(.systemGray6),
                size: 36,
                action: viewModel.didTapExit
            )
            .accessibilityLabel("Close")
        }
    }

    func timerPill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock").font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
        }
        .foregroundColor(viewModel.isTimeLow ? .red : .primary)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            Capsule().fill(viewModel.isTimeLow ? Color.red.opacity(0.12) : Color(.systemGray6))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left \(text)")
    }

    @ViewBuilder
    var phaseContent: some View {
        switch viewModel.phase {
        case .starting:
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                Text("Opening quiz...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)

        case .failed(let message, let canRetry):
            failedView(message: message, canRetry: canRetry)

        case .playing:
            playingView

        case .finished(let result):
            QuizResultContentView(result: result, onDone: viewModel.didTapDone)
        }
    }

    func failedView(message: String, canRetry: Bool) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                if canRetry {
                    CSPrimaryButton(title: "Try again", systemImage: "arrow.clockwise", action: viewModel.didTapRetryStart)
                }
                if viewModel.canViewResult {
                    CSPrimaryButton(title: "View result", action: viewModel.didTapViewResult)
                }
                CSSecondaryButton(title: "Close", action: viewModel.didTapDone)
            }
            .frame(maxWidth: 280)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    var playingView: some View {
        VStack(spacing: 0) {
            progressHeader
            if viewModel.isTimeUp {
                CSInfoBanner(style: .danger, title: "Time's up", message: "Your answers are being submitted.",
                             systemImage: "clock.badge.exclamationmark")
                    .padding(.horizontal)
                    .padding(.top, 12)
            }
            ScrollView {
                if let question = viewModel.currentQuestion {
                    questionBody(question)
                        .padding()
                }
            }
            // new question starts at the top, not wherever the last one was scrolled to
            .id(viewModel.currentQuestion?.attemptQuestionId)
            footer
        }
    }

    var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.positionText)
                Spacer()
                Text(viewModel.answeredText)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(CSTheme.primaryColor)
                        .frame(width: proxy.size.width * viewModel.progress)
                }
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
            .accessibilityHidden(true)

            QuizQuestionPaletteView(
                questionIDs: viewModel.questions.map(\.attemptQuestionId),
                currentIndex: viewModel.currentIndex,
                answeredIDs: Set(viewModel.questions.map(\.attemptQuestionId).filter { viewModel.sheet.isAnswered($0) }),
                onSelect: viewModel.didSelectQuestion(at:)
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    func questionBody(_ question: DM.PlayerQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(question.questionText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let instruction = question.learnerInstruction?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !instruction.isEmpty {
                    Text(instruction)
                        .font(.system(size: 13.5))
                        .foregroundColor(.secondary)
                }
                if question.isMultiple {
                    Text("Select all that apply")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(CSTheme.primaryColor)
                }
            }
            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                    QuizOptionRowView(
                        letter: DM.optionLetter(index),
                        text: option.optionText,
                        isSelected: viewModel.isSelected(option.id),
                        isMultiple: question.isMultiple,
                        isEnabled: viewModel.acceptsAnswers,
                        onTap: { viewModel.didSelectOption(option) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var footer: some View {
        HStack(spacing: 12) {
            CSSecondaryButton(title: "Previous", systemImage: "chevron.left",
                              isEnabled: !viewModel.isFirstQuestion && !viewModel.isSubmitting,
                              height: 46, expands: false, action: viewModel.didTapPrevious)
            Text(viewModel.marksText)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
            if viewModel.showsSubmit {
                CSPrimaryButton(title: "Submit Quiz", isEnabled: !viewModel.isSubmitting, tint: .green,
                                height: 46, expands: false, action: viewModel.didTapSubmit)
            } else {
                CSPrimaryButton(title: "Next", systemImage: "chevron.right", height: 46, expands: false,
                                imageTrailing: true, action: viewModel.didTapNext)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    QuizPlayerView(
        router: router,
        navModel: .init(quizID: 97, kind: .pre, title: "class56 — pre check", onClose: {})
    )
}
