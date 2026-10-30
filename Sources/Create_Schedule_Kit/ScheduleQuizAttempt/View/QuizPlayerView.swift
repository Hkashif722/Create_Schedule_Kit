//
//  QuizPlayerView.swift
//  Create_Schedule_Kit
//
//  Full-screen quiz player, laid out like the main app's assessment from AssessmentKit views:
//  question, options, palette + back / forward + Submit Quiz. Result shows in place once submitted.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import AssessmentKit

struct QuizPlayerView: View {

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
            QuizResultContentView(
                result: result,
                notice: viewModel.isTimeUp ? "Time is up. Your quiz has been submitted." : nil,
                onDone: viewModel.didTapDone
            )
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
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isTimeUp {
                CSInfoBanner(style: .danger, title: "Time's up", message: "Your answers are being submitted.",
                             systemImage: "clock.badge.exclamationmark")
            }
            if let question = viewModel.currentQuestion {
                questionHeader
                // shared option list brings its own ScrollView. wrap it in another and scroll breaks
                QuizSelectionView(
                    questionID: question.attemptQuestionId,
                    options: viewModel.currentOptions,
                    optionType: viewModel.currentOptionType,
                    onSelect: viewModel.didSelectOption
                )
                .disabled(!viewModel.acceptsAnswers)
                .opacity(viewModel.acceptsAnswers ? 1 : 0.6)
            } else {
                Spacer()
            }
            bottomControl
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    var questionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            SharedAssessmentHeaderView(contentType: "", questionText: viewModel.questionText)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue("\(viewModel.positionText), \(viewModel.answeredText)")
            if let instruction = viewModel.instructionText {
                Text(instruction)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            }
            if viewModel.isMultipleSelection || !viewModel.marksText.isEmpty {
                HStack(spacing: 8) {
                    if viewModel.isMultipleSelection {
                        Text("Select all that apply")
                            .foregroundStyle(CSTheme.primaryColor)
                    }
                    Spacer(minLength: 0)
                    Text(viewModel.marksText)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var bottomControl: some View {
        QuizBottomControlView(
            currentIndex: viewModel.currentIndex,
            totalQuestions: viewModel.questions.count,
            isFirstQuestion: viewModel.isFirstQuestion,
            showsSubmit: viewModel.showsSubmit,
            isSubmitEnabled: !viewModel.isSubmitting,
            segments: viewModel.segments,
            onPrevious: viewModel.didTapPrevious,
            onNext: viewModel.didTapNext,
            onSelectQuestion: viewModel.didSelectQuestion(at:),
            onSubmit: viewModel.didTapSubmit
        )
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
