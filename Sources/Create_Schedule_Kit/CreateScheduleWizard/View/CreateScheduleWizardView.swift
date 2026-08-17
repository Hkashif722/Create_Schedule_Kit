//
//  CreateScheduleWizardView.swift
//  Create_Schedule_Kit
//
//  Root view of the Create Schedule wizard. Renders the progress header and the
//  current step. Steps own their own view models and write into the shared draft.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct CreateScheduleWizardView: View {

    @StateObject private var viewModel: CreateScheduleWizardViewModel
    private let router: AnyRouter

    init(router: AnyRouter, mode: WizardMode = .create, onFinish: ((CreateScheduleKitEvent) -> Void)? = nil) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: CreateScheduleWizardViewModel(router: router, mode: mode, onFinish: onFinish)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            CSStepTracker(steps: viewModel.stepLabels, currentStep: viewModel.currentStep)
                .padding(.horizontal)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))

            stepContent
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .navigationTitle(viewModel.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
    }

    @ViewBuilder
    private var stepContent: some View {
        // Steps copy the draft in their view-model inits, so in edit mode nothing
        // renders until the fetched schedule has hydrated the draft.
        if !viewModel.isHydrated {
            Color.clear
        } else {
            switch viewModel.currentStep {
            case 1:
                ScheduleBasicDetailsView(
                    router: router,
                    draft: viewModel.draft,
                    isEditMode: viewModel.mode.isEdit,
                    onBack: viewModel.goBack,
                    onContinue: viewModel.goNext
                )
            case 2:
                ScheduleLogisticsView(
                    router: router,
                    draft: viewModel.draft,
                    isEditMode: viewModel.mode.isEdit,
                    onBack: viewModel.goBack,
                    onContinue: viewModel.goNext
                )
            case 3:
                ScheduleFeedbackView(
                    router: router,
                    draft: viewModel.draft,
                    isEditMode: viewModel.mode.isEdit,
                    onBack: viewModel.goBack,
                    onContinue: viewModel.goNext,
                    onSkipCreate: viewModel.createSchedule
                )
            default:
                EmptyView()
            }
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    SwiftUtilityEnvironment.configure(
        SwiftUtilityConfig(
            encryptionDecryptionKey: "preview-key",
            isBlobEnabled: true,
            orgCode: "preview",
            configurableDate: "dd-MM-yyyy",
            baseURL: "",
            lxpOPath: "",
            lxpBlobPath: "",
            lxpBlobPath1: ""
        )
    )
    return CreateScheduleWizardView(router: router)
}
