//
//  LearnerScheduleQuizView.swift
//  Create_Schedule_Kit
//
//  Learner entry point: the schedule's Pre and Post quiz cards. Only slots the manager created
//  show up; Start / Resume / View result open full-screen on top.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct LearnerScheduleQuizView: View {

    @StateObject private var viewModel: LearnerScheduleQuizViewModel

    init(router: AnyRouter, scheduleID: Int) {
        _viewModel = StateObject(
            wrappedValue: LearnerScheduleQuizViewModel(router: router, scheduleID: scheduleID)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension LearnerScheduleQuizView {

    var header: some View {
        ZStack {
            Text("Schedule Quiz")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { viewModel.didTapBack() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    var content: some View {
        if viewModel.showsInitialSpinner {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.loadFailed {
            messageView(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load quizzes",
                message: "Check your connection and try again.",
                actionTitle: "Try again",
                action: viewModel.reload
            )
        } else if viewModel.showsEmptyState {
            messageView(
                systemImage: "checklist",
                title: "No quizzes for this schedule yet.",
                message: "Pre and post quizzes appear here once your trainer publishes them.",
                actionTitle: nil,
                action: {}
            )
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.slots) { slot in
                        LearnerQuizCardView(
                            slot: slot,
                            onStart: { viewModel.didTapStart(slot) },
                            onResume: { viewModel.didTapResume(slot) },
                            onViewResult: { viewModel.didTapViewResult(slot) }
                        )
                    }
                }
                .padding()
            }
        }
    }

    func messageView(systemImage: String, title: String, message: String,
                     actionTitle: String?, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle {
                CSSecondaryButton(title: actionTitle, systemImage: "arrow.clockwise", action: action)
                    .frame(maxWidth: 220)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    LearnerScheduleQuizView(router: router, scheduleID: 4826)
}
