//
//  CreateScheduleWizardViewModel.swift
//  Create_Schedule_Kit
//
//  Coordinator for the multi-step Create Schedule wizard. Owns the shared
//  `ScheduleDraft` and drives step navigation. The Feedback step is org-configurable
//  (`ConfigurableParameters/GetValue/Schfbk`) — when it is off the wizard is two steps
//  and Venue submits the schedule.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class CreateScheduleWizardViewModel: BaseViewModel {

    // MARK: - State
    let draft = ScheduleDraft()
    let mode: WizardMode
    var stepLabels: [String] { isFeedbackEnabled ? ["Basics", "Venue", "Feedback"] : ["Basics", "Venue"] }
    var totalSteps: Int { stepLabels.count }
    @Published var currentStep: Int = 1

    /// Schedule-level feedback is an org setting. Starts off and is only turned on by an
    /// explicit "Yes" from the config API — a failed lookup leaves the step hidden rather
    /// than offering a module the organization does not collect.
    @Published private(set) var isFeedbackEnabled: Bool = false

    /// The config lookup has settled (either way). Steps stay unrendered until then so the
    /// step tracker never flickers from three labels down to two.
    @Published private(set) var isConfigLoaded: Bool = false

    /// Edit mode fetches + prefills the draft before step 1 may render (step view
    /// models copy the draft in their inits). Always true in create mode.
    @Published private(set) var isHydrated: Bool

    /// Everything the first step depends on is resolved.
    var isReady: Bool { isConfigLoaded && isHydrated }

    /// The fetched schedule in edit mode — the base the update payload echoes back.
    private(set) var editBase: EditScheduleDataModel.ScheduleDetailsResponse?

    private let onFinish: ((CreateScheduleKitEvent) -> Void)?

    var navTitle: String { mode.isEdit ? "Edit Schedule" : "Create Schedule" }

    // MARK: - Init
    init(router: AnyRouter, mode: WizardMode = .create, onFinish: ((CreateScheduleKitEvent) -> Void)? = nil) {
        self.mode = mode
        self.isHydrated = !mode.isEdit
        self.onFinish = onFinish
        super.init(router: router)
        Task { [weak self] in await self?.loadFeedbackConfig() }
        if case .edit(let scheduleID) = mode {
            Task { [weak self] in await self?.loadEditData(scheduleID: scheduleID) }
        }
    }

    /// `ConfigurableParameters/GetValue/Schfbk` → `{"value":"Yes"}` / `{"value":"No"}`.
    @MainActor
    private func loadFeedbackConfig() async {
        do {
            let response = try await ApiService.shared.requestGetHeader(
                type: ScheduleListDataModel.ConfigValueResponse.self,
                model: ScheduleListDataModel.GetConfigValueRequest(key: "Schfbk")
            )
            isFeedbackEnabled = response.isYes
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
        isConfigLoaded = true
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

    /// Submit the collected draft — create posts to `ILTSchedule/PostWithMeeting`,
    /// edit posts the echo-back payload to `ILTSchedule/UpdateILTScheduleWithMeeting`.
    private func finish() {
        Task { [weak self] in
            guard let self else { return }
            if self.mode.isEdit {
                await self.submitUpdate()
            } else {
                await self.submit()
            }
        }
    }

    @MainActor
    private func submit() async {
        loadingState = .loading(message: "Creating schedule...")
        do {
            let payload = CreateScheduleWizardDataModel.Payload(draft: draft)
            // `PostWithMeeting` asks the server to mint the meeting. When the body already
            // carries one — a typed Teams link or a generated provider meeting — the plain
            // route is the one that accepts it, matching the web client.
            let response: CreateScheduleWizardDataModel.CreateScheduleResponse
            if payload.carriesClientMeetingDetails {
                response = try await ApiService.shared.requestPostHeader(
                    type: CreateScheduleWizardDataModel.CreateScheduleResponse.self,
                    model: CreateScheduleWizardDataModel.CreateScheduleRequest(),
                    payload: payload
                )
            } else {
                response = try await ApiService.shared.requestPostHeader(
                    type: CreateScheduleWizardDataModel.CreateScheduleResponse.self,
                    model: CreateScheduleWizardDataModel.PostWithMeetingRequest(),
                    payload: payload
                )
            }
            guard (response.statusCode ?? 0) == 200 else {
                loadingState = .none
                toast = Toast(style: .error, message: response.serverMessage ?? "Could not create schedule.")
                return
            }
            loadingState = .none
            if !permissions.canNominate
                || ScheduleDateRules.isStartInPast(startDate: draft.startDate, startTime: draft.startTime) {
                completeAndDismiss()
            } else {
                promptNomination()
            }
        } catch let error as APIError {
            // `handleAPIError` only understands a converted error; handed the raw one it
            // falls back to a generic message and the server's reason is lost. Same
            // conversion the cancel flow does.
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
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

// MARK: - Edit mode (hydration + update)
extension CreateScheduleWizardViewModel {

    /// Fetch the full schedule, resolve the module/timezone picker items, and prefill
    /// the draft. The wizard renders its steps only after this completes.
    @MainActor
    private func loadEditData(scheduleID: Int) async {
        loadingState = .loading(message: "Loading schedule...")
        do {
            let details = try await ApiService.shared.requestPostHeader(
                type: EditScheduleDataModel.ScheduleDetailsResponse.self,
                model: EditScheduleDataModel.GetScheduleDetailsByIDRequest(),
                payload: EditScheduleDataModel.GetScheduleDetailsByIDRequest.Payload(scheduleId: scheduleID)
            )
            // Both lookups are non-fatal — the mapper synthesizes display-equivalent
            // items from the response when a list is unavailable.
            async let modulesFetch = fetchModulesQuietly(courseID: details.courseID)
            async let timezonesFetch = fetchTimezonesQuietly()
            let (modules, timezones) = await (modulesFetch, timezonesFetch)

            editBase = details
            draft.apply(details: details, modules: modules, timezones: timezones)
            isHydrated = true
            loadingState = .none
        } catch {
            // Without the base schedule the editor is unusable — surface and leave.
            handleAPIError(error, resetLoadingState: true, showToast: true)
            router.dismissScreen()
        }
    }

    private func fetchModulesQuietly(courseID: Int?) async -> [ScheduleBasicDetailsDataModel.ModuleItem] {
        guard let courseID else { return [] }
        return (try? await ApiService.shared.requestGetHeader(
            type: [ScheduleBasicDetailsDataModel.ModuleItem].self,
            model: ScheduleBasicDetailsDataModel.ModulesByCourseRequest(courseID: "\(courseID)")
        )) ?? []
    }

    private func fetchTimezonesQuietly() async -> [ScheduleBasicDetailsDataModel.TimezoneItem] {
        (try? await ApiService.shared.requestGetHeader(
            type: [ScheduleBasicDetailsDataModel.TimezoneItem].self,
            model: ScheduleBasicDetailsDataModel.TimezonesRequest()
        )) ?? []
    }

    @MainActor
    private func submitUpdate() async {
        guard let base = editBase else {
            toast = Toast(style: .error, message: "Schedule details are not loaded yet.")
            return
        }
        loadingState = .loading(message: "Updating schedule...")
        do {
            let payload = EditScheduleDataModel.UpdatePayload(base: base, draft: draft)
            let response = try await ApiService.shared.requestPostHeader(
                type: CreateScheduleWizardDataModel.CreateScheduleResponse.self,
                model: EditScheduleDataModel.UpdateWithMeetingRequest(),
                payload: payload
            )
            guard (response.statusCode ?? 0) == 200 else {
                loadingState = .none
                toast = Toast(style: .error, message: response.serverMessage ?? "Could not update schedule.")
                return
            }
            loadingState = .none
            // No nomination prompt on update — the list shows the success toast
            // (a toast set on this dismissed screen would never render).
            let event = CreateScheduleKitEvent.scheduleUpdated(scheduleCode: draft.scheduleCode)
            eventPublisher.publish(event)
            onFinish?(event)
            router.dismissScreen()
        } catch let error as APIError {
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
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
