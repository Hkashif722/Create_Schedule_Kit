//
//  CreateScheduleWizardViewModel.swift
//  Create_Schedule_Kit
//
//  Coordinator for the multi-step Create Schedule wizard. Owns the shared
//  `ScheduleDraft` and drives step navigation. The Feedback step is org-configurable
//  (`ConfigurableParameters/GetValue/Schfbk`) — when it is off Venue submits the schedule.
//
//  Quiz is always the last step and comes after the submit: the Pre/Post quiz API is keyed
//  by schedule id, which only exists once the schedule is saved.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class CreateScheduleWizardViewModel: BaseViewModel {

    enum Step: Equatable {
        case basics, venue, feedback, quiz

        var label: String {
            switch self {
            case .basics:   return "Basics"
            case .venue:    return "Venue"
            case .feedback: return "Feedback"
            case .quiz:     return "Quiz"
            }
        }
    }

    // MARK: - State
    let draft = ScheduleDraft()
    let mode: WizardMode
    var steps: [Step] { isFeedbackEnabled ? [.basics, .venue, .feedback, .quiz] : [.basics, .venue, .quiz] }
    var stepLabels: [String] { steps.map(\.label) }
    var totalSteps: Int { steps.count }
    @Published var currentStep: Int = 1

    var currentStepKind: Step? {
        steps.indices.contains(currentStep - 1) ? steps[currentStep - 1] : nil
    }

    /// The step whose primary action saves the schedule — the one right before Quiz.
    private var submitStep: Int { totalSteps - 1 }

    var isOnQuizStep: Bool { currentStepKind == .quiz }

    /// Set once the schedule exists (created and looked up by code, or the one being edited).
    @Published private(set) var savedScheduleID: Int?

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
        if currentStep < submitStep {
            currentStep += 1
        } else if currentStep == submitStep {
            finish()
        } else {
            finishQuizStep()
        }
    }

    func goBack() {
        // The schedule is already saved behind the Quiz step; there is nothing to go back to.
        guard !isOnQuizStep else { return }
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
            // The create body answers no id, so the quiz step looks the new schedule up by its code.
            loadingState = .loading(message: "Preparing quiz step...")
            let scheduleID = await resolveScheduleID(code: draft.scheduleCode)
            loadingState = .none
            if let scheduleID {
                savedScheduleID = scheduleID
                currentStep = totalSteps
            } else {
                finishCreate()
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
            await hydrateTeamsMeeting(details: details)
            isHydrated = true
            loadingState = .none
        } catch {
            // Without the base schedule the editor is unusable — surface and leave.
            handleAPIError(error, resetLoadingState: true, showToast: true)
            router.dismissScreen()
        }
    }

    /// Fills the Teams link from the schedule's stored meeting.
    ///
    /// `GetScheduleDetailsByID` answers `teamsScheduleDetails: null`, so the link has to be
    /// looked up by schedule code. Teams-only — `lookupCode` owns that rule. Non-fatal: a
    /// failure leaves whatever the details response carried, and the rest of the editor
    /// still works.
    @MainActor
    private func hydrateTeamsMeeting(details: EditScheduleDataModel.ScheduleDetailsResponse) async {
        guard let code = EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest.lookupCode(
            webinarType: draft.webinarType,
            scheduleCode: details.scheduleCode
        ) else { return }

        guard let meeting = try? await ApiService.shared.requestPostHeader(
            type: JSONValue.self,
            model: EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest(),
            payload: EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest.Payload(code: code)
        ) else { return }

        // Kept whole rather than modelled field by field: the update echoes it back, and
        // every key the server sent has to survive the round trip.
        draft.teamsMeeting = meeting
        if let link = meeting.firstString(forKey: "joinUrl"), !link.isEmpty {
            draft.teamsLink = link
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
            if case .edit(let scheduleID) = mode {
                savedScheduleID = scheduleID
                currentStep = totalSteps
            } else {
                finishUpdate()
            }
        } catch let error as APIError {
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }
}

// MARK: - Quiz step
extension CreateScheduleWizardViewModel {

    /// What the Quiz step needs. Nil until the schedule is saved.
    var quizNavModel: NavigationViewModel.ScheduleQuizNavModel? {
        guard let savedScheduleID else { return nil }
        let name = draft.module?.title ?? draft.course?.title ?? ""
        return .init(scheduleID: savedScheduleID, scheduleCode: draft.scheduleCode, displayName: name)
    }

    /// Finish on the Quiz step: create goes on to the nomination prompt as before, edit hands
    /// the list its "updated" event.
    func finishQuizStep() {
        if mode.isEdit {
            finishUpdate()
        } else {
            finishCreate()
        }
    }

    private func finishCreate() {
        if !permissions.canNominate
            || ScheduleDateRules.isStartInPast(startDate: draft.startDate, startTime: draft.startTime) {
            completeAndDismiss()
        } else {
            promptNomination()
        }
    }

    /// No nomination prompt on update — the list shows the success toast (a toast set on this
    /// dismissed screen would never render).
    private func finishUpdate() {
        let event = CreateScheduleKitEvent.scheduleUpdated(scheduleCode: draft.scheduleCode)
        eventPublisher.publish(event)
        onFinish?(event)
        router.dismissScreen()
    }

    /// `GetScheduleData` filtered on the `scheduleCode` column. Nil on any failure — the wizard
    /// then skips the Quiz step and quizzes can still be added from the schedule card.
    @MainActor
    private func resolveScheduleID(code: String) async -> Int? {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        let payload = ScheduleListDataModel.ListPayload(
            page: 1,
            pageSize: 10,
            search: ScheduleListDataModel.FilterColumn.scheduleCode.apiValue,
            searchText: code,
            showAllData: "true"
        )
        let schedules = try? await ApiService.shared.requestPostHeader(
            type: [ScheduleListDataModel.Schedule].self,
            model: ScheduleListDataModel.GetScheduleDataRequest(),
            payload: payload
        )
        return schedules?.first {
            ($0.scheduleCode ?? "").caseInsensitiveCompare(code) == .orderedSame
        }?.id
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
