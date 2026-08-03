//
//  CreateScheduleWizardViewModel.swift
//  Create_Schedule_Kit
//
//  Coordinator for the multi-step Create Schedule wizard. Owns the shared
//  `ScheduleDraft` and drives step navigation. Steps 3 & 4 are placeholders.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class CreateScheduleWizardViewModel: BaseViewModel {

    // MARK: - State
    let draft = ScheduleDraft()
    let stepLabels = ["Basics", "Venue", "Feedback"]
    var totalSteps: Int { stepLabels.count }
    @Published var currentStep: Int = 1

    private let onFinish: ((CreateScheduleKitEvent) -> Void)?

    // MARK: - Init
    init(router: AnyRouter, onFinish: ((CreateScheduleKitEvent) -> Void)? = nil) {
        self.onFinish = onFinish
        super.init(router: router)
    }

}

// MARK: - Navigation
extension CreateScheduleWizardViewModel {

    func goNext() {
        if currentStep < totalSteps {
            currentStep += 1
        } else {
            finish()
        }
    }

    func goBack() {
        if currentStep > 1 {
            currentStep -= 1
        } else {
            cancel()
        }
    }

    /// Create the schedule now, skipping any remaining optional steps.
    func createSchedule() {
        finish()
    }

    private func cancel() {
        let event = CreateScheduleKitEvent.cancelled
        eventPublisher.publish(event)
        onFinish?(event)
        goBack(toRoot: false)
    }

    /// Submit the collected draft to `ILTSchedule/PostWithMeeting`.
    private func finish() {
        Task { [weak self] in await self?.submit() }
    }

    @MainActor
    private func submit() async {
        loadingState = .loading(message: "Creating schedule...")
        do {
            let payload = CreateScheduleWizardDataModel.Payload(draft: draft)
            let response = try await ApiService.shared.requestPostHeader(
                type: CreateScheduleWizardDataModel.CreateScheduleResponse.self,
                model: CreateScheduleWizardDataModel.PostWithMeetingRequest(),
                payload: payload
            )
            guard (response.statusCode ?? 0) == 200 else {
                loadingState = .none
                toast = Toast(style: .error, message: response.message ?? "Could not create schedule.")
                return
            }
            loadingState = .none
            // Schedule created — offer to nominate users before finishing.
            promptNomination()
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }

    private func goBack(toRoot: Bool) {
        Task { @MainActor [weak self] in
            self?.router.dismissScreen()
        }
    }
}

// MARK: - Post-create nomination
extension CreateScheduleWizardViewModel {

    /// Ask whether to nominate users for the freshly-created schedule (Image #1).
    @MainActor
    private func promptNomination() {
        let model = CustomAlertPopupModel(
            title: "Create",
            alertType: .none,
            content: {
                Text("Do you want to nominate users for this schedule?")
                    .multilineTextAlignment(.center)
                    .padding()
            },
            primaryButtonTitle: "Yes",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
                self?.presentNominateSheet()
            },
            secondaryButtonTitle: "No",
            secondaryAction: { [weak self] in
                self?.router.dismissModal()
                self?.completeAndDismiss()
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.customAlertPopupView(model))
        )
    }

    /// Present the Nominate Users bottom sheet (Image #2). A short delay lets the
    /// confirmation modal finish dismissing before the sheet is presented.
    @MainActor
    private func presentNominateSheet() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self else { return }
            let navModel = NavigationViewModel.NominateUsersNavModel(
                scheduleCode: self.draft.scheduleCode,
                courseID: self.draft.course?.id ?? 0,
                moduleID: self.draft.module?.id ?? 0,
                onComplete: { [weak self] in self?.completeAndDismiss() }
            )
            NavigationService.shared.navigate(
                using: self.router,
                to: AppNavigationDestination.nominateUsers(navModel)
            )
        }
    }

    /// Publish the created event, notify the host, and dismiss the wizard.
    @MainActor
    private func completeAndDismiss() {
        let event = CreateScheduleKitEvent.scheduleCreated(scheduleCode: draft.scheduleCode)
        eventPublisher.publish(event)
        onFinish?(event)
        router.dismissScreen()
    }
}
