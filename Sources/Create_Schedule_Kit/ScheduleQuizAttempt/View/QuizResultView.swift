//
//  QuizResultView.swift
//  Create_Schedule_Kit
//
//  "View result" for a submitted attempt. Same body as the player shows after Submit.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct QuizResultView: View {

    @StateObject private var viewModel: QuizResultViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.LearnerQuizResultNavModel) {
        _viewModel = StateObject(
            wrappedValue: QuizResultViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            LearnerQuizTopBar(kind: viewModel.navModel.kind, title: viewModel.navModel.title) {
                SwiftUIUtility.CircleCloseButton(
                    foregroundColor: .secondary,
                    backgroundColor: Color(.systemGray6),
                    size: 36,
                    action: viewModel.didTapDone
                )
                .accessibilityLabel("Close")
            }
            content
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension QuizResultView {

    @ViewBuilder
    var content: some View {
        switch viewModel.phase {
        case .loading:
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .frame(maxWidth: .infinity)

        case .loaded(let result):
            QuizResultContentView(result: result, onDone: viewModel.didTapDone)

        case .notCompleted:
            messageView(
                message: "This attempt is still in progress.",
                primaryTitle: viewModel.canResume ? "Resume quiz" : nil,
                primaryAction: viewModel.didTapResume
            )

        case .failed(let message):
            messageView(message: message, primaryTitle: "Try again", primaryAction: viewModel.didTapRetry)
        }
    }

    func messageView(message: String, primaryTitle: String?, primaryAction: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                if let primaryTitle {
                    CSPrimaryButton(title: primaryTitle, action: primaryAction)
                }
                CSSecondaryButton(title: "Close", action: viewModel.didTapDone)
            }
            .frame(maxWidth: 280)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    QuizResultView(
        router: router,
        navModel: .init(attemptID: 12, kind: .post, title: "class56 — post check", onResume: nil)
    )
}
