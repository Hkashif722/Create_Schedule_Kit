//
//  ScheduleQuizView.swift
//  Create_Schedule_Kit
//
//  Pre & Post quiz slots for one schedule. Standalone it brings its own header; as the wizard's
//  last step the wizard owns the title + step tracker and this view adds the Finish footer.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct ScheduleQuizView: View {

    typealias DM = ScheduleQuizDataModel

    @StateObject private var viewModel: ScheduleQuizViewModel

    init(router: AnyRouter,
         navModel: NavigationViewModel.ScheduleQuizNavModel,
         presentation: ScheduleQuizViewModel.Presentation) {
        _viewModel = StateObject(
            wrappedValue: ScheduleQuizViewModel(router: router, navModel: navModel, presentation: presentation)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.presentation.isWizardStep {
                header
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CSInfoBanner(
                        style: .danger,
                        title: "Edit Constraint",
                        message: "Questions can be edited only until a participant starts the assessment. After the first attempt the quiz is locked."
                    )
                    CSInfoBanner(
                        style: .info,
                        title: "ILT Schedule Report",
                        message: "Pre & Post quiz scores and pass percentages will appear per learner in the ILT Schedule Report."
                    )
                    slots
                }
                .padding()
            }
            if viewModel.presentation.isWizardStep {
                CSNavFooter(
                    showBack: false,
                    nextTitle: "Finish",
                    nextSystemImage: "checkmark",
                    onNext: viewModel.didTapFinish
                )
            }
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .navigationBarHidden(!viewModel.presentation.isWizardStep)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension ScheduleQuizView {

    var header: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Pre & Post Quiz")
                    .font(.system(size: 20, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if !viewModel.navModel.scheduleCode.isEmpty {
                    Text(viewModel.navModel.scheduleCode)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            HStack {
                Button(action: viewModel.didTapBack) {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    var slots: some View {
        if viewModel.loadFailed {
            VStack(spacing: 10) {
                Text("Couldn't load this schedule's quizzes.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                CSSecondaryButton(title: "Retry", systemImage: "arrow.clockwise", action: viewModel.didTapRetry)
                    .frame(maxWidth: 200)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ForEach(DM.QuizKind.allCases) { kind in
                QuizSlotCardView(
                    kind: kind,
                    quiz: viewModel.quiz(kind),
                    isEnabled: Binding(
                        get: { viewModel.isEnabled(kind) },
                        set: { viewModel.setEnabled(kind, isOn: $0) }
                    ),
                    isToggleEnabled: viewModel.canToggle(kind),
                    emptyText: viewModel.emptySlotText(kind),
                    onEdit: { viewModel.didTapEdit(kind) },
                    onDelete: { viewModel.didTapDelete(kind) }
                )
            }
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    ScheduleQuizView(
        router: router,
        navModel: .init(scheduleID: 4826, scheduleCode: "SC9769", displayName: "22176_class56"),
        presentation: .standalone
    )
}
