//
//  ScheduleBasicDetailsViewModel.swift
//  Create_Schedule_Kit
//
//  Step 1 logic: schedule code, course/module/timezone loading, delivery + webinar
//  credentials (with reveal/decrypt), date auto-populate + range rules, holidays.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class ScheduleBasicDetailsViewModel: BaseViewModel {

    // MARK: - Dependencies
    private let draft: ScheduleDraft
    /// Edit mode locks course, module, delivery and webinar; schedule-code editing follows ASCFE.
    let isEditMode: Bool
    private let onBack: () -> Void
    private let onContinue: () -> Void

    // MARK: - Published State
    @Published var scheduleCode: String = ""
    @Published private(set) var isScheduleCodeEditable: Bool = false
    @Published var courseResults: [ScheduleBasicDetailsDataModel.Course] = []
    @Published var selectedCourse: ScheduleBasicDetailsDataModel.Course?
    @Published var modules: [ScheduleBasicDetailsDataModel.ModuleItem] = []
    @Published var selectedModule: ScheduleBasicDetailsDataModel.ModuleItem?

    @Published var deliveryMode: DeliveryMode = .offline
    @Published var webinarType: WebinarType?
    @Published var credentials: [ScheduleBasicDetailsDataModel.Credential]?
    @Published var selectedCredential: ScheduleBasicDetailsDataModel.Credential?
    @Published var isCredentialRevealed: Bool = false

    @Published var timezones: [ScheduleBasicDetailsDataModel.TimezoneItem] = []
    @Published var selectedTimezone: ScheduleBasicDetailsDataModel.TimezoneItem?

    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var registrationEndDate: Date?
    @Published var startTime: String?
    @Published var endTime: String?

    /// Bumped whenever the end-time field has to resync its display from the model — a
    /// refused selection or a clear. `TimePickerTextField` stores the picked time in its
    /// own `@State` and adopts `initialTimeString` only on first appearance, so changing
    /// the model alone cannot pull a rejected value back off the screen. The view keys the
    /// field on this token so it is rebuilt from the model instead.
    @Published private(set) var endTimeFieldToken: Int = 0

    /// Bumped whenever a date field has to resync its display from the model — currently
    /// a refused Sunday selection. `DatePickerTextFieldPkg` keeps the tapped day in its
    /// own `@State`, so clearing the model alone cannot pull a rejected value off the
    /// screen; the view keys the date fields on this token so they are rebuilt from the
    /// model instead. Same remount trick as `endTimeFieldToken`.
    @Published private(set) var dateFieldToken: Int = 0

    /// `ATPTLWCS` — unlocks the hand-entered Teams link. Defaults to off: a config outage
    /// must not surface a field the tenant has not enabled.
    @Published private(set) var isTeamsStaticLinkEnabled: Bool = false
    @Published var teamsLink: String = ""
    private var hasRequestedTeamsLinkConfig = false
    /// Bumped when the link field must resync from the model — currently a provider switch.
    /// `MultilineTextInputField` adopts `initialText` only on first appear, so the view keys
    /// the field on this token. Same trick as `endTimeFieldToken`.
    @Published private(set) var linkFieldToken: Int = 0

    @Published var holidaysEnabled: Bool = false
    @Published var holidays: [HolidayDay] = []

    private let dateFormat = CreateScheduleKitAPIManager.shared.getConfiguaredDate
    private var hasRequestedScheduleCodeConfig = false

    // MARK: - Init
    init(router: AnyRouter, draft: ScheduleDraft, isEditMode: Bool = false, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.draft = draft
        self.isEditMode = isEditMode
        self.onBack = onBack
        self.onContinue = onContinue
        super.init(router: router)
        restoreFromDraft()
    }

    func loadData() {
        if !hasRequestedScheduleCodeConfig {
            hasRequestedScheduleCodeConfig = true
            Task { [weak self] in await self?.fetchScheduleCodeEditingConfig() }
        }
        if !hasRequestedTeamsLinkConfig {
            hasRequestedTeamsLinkConfig = true
            Task { [weak self] in await self?.fetchTeamsLinkConfig() }
        }
        // Edit mode keeps the fetched schedule's own code — never mint a new one.
        if scheduleCode.isEmpty, !isEditMode {
            Task { [weak self] in await self?.fetchScheduleCode() }
        }
        if timezones.isEmpty {
            Task { [weak self] in await self?.fetchTimezones() }
        }
    }

    private func restoreFromDraft() {
        scheduleCode = draft.scheduleCode
        selectedCourse = draft.course
        selectedModule = draft.module
        deliveryMode = draft.deliveryMode
        webinarType = draft.webinarType
        credentials = draft.credential
        selectedCredential = draft.credential?.first
        selectedTimezone = draft.timezone
        startDate = draft.startDate
        endDate = draft.endDate
        registrationEndDate = draft.registrationEndDate
        startTime = draft.startTime.map { ScheduleDateRules.canonical24HourTime($0) ?? $0 }
        endTime = draft.endTime.map { ScheduleDateRules.canonical24HourTime($0) ?? $0 }
        teamsLink = draft.teamsLink ?? ""
        holidays = draft.holidays
        holidaysEnabled = ScheduleDateRules.hasMarkableHolidays(start: draft.startDate, end: draft.endDate)
            && draft.holidays.contains { $0.isHoliday }
    }
}

// MARK: - Derived UI State
extension ScheduleBasicDetailsViewModel {

    var showWebinarSection: Bool { deliveryMode == .online }

    var showCredentialSection: Bool {
        showWebinarSection
            && (webinarType?.hasCredentialAPI ?? false)
            && !(credentials?.isEmpty ?? true)
            && selectedCredential != nil
    }

    var webinarOptions: [WebinarType] { WebinarType.allCases }

    var deliveryOptions: [DeliveryMode] { DeliveryMode.allCases }

    // Read-only category rows shown in edit mode (from the locked module).
    var categoryText: String { selectedModule?.category ?? "" }
    var subCategoryText: String { selectedModule?.subCategory ?? "" }
    var subSubCategoryText: String { selectedModule?.subSubCategory ?? "" }

    /// The credential identity (email) — decrypted when revealed, masked otherwise.
    var credentialDisplayValue: String {
        guard let raw = selectedCredential?.teamsEmail, !raw.isEmpty else { return "—" }
        guard isCredentialRevealed else { return String(repeating: "•", count: min(raw.count, 12)) }
        let decrypted = EncryptDecryptUtility.shared.newDecryptString(responseStr: raw)
        return decrypted.isEmpty ? raw : decrypted
    }

    // MARK: Meeting link

    /// Teams asks for a link by hand once `ATPTLWCS` is on. Hidden in edit mode:
    /// `UpdatePayload` echoes the fetched schedule's own meeting details and never reads
    /// the draft, so an editable link there would go nowhere.
    var showTeamsLinkField: Bool {
        !isEditMode
            && showWebinarSection
            && WebinarLinkRules.usesStaticLink(for: webinarType, isEnabled: isTeamsStaticLinkEnabled)
    }

    /// The link is only required where it is actually shown.
    var requiresTeamsLink: Bool { showTeamsLinkField }

    /// Only complains once something has been typed — an untouched required field is
    /// already marked by its asterisk.
    var teamsLinkError: String? {
        guard requiresTeamsLink,
              !WebinarLinkRules.normalizedLink(teamsLink).isEmpty,
              !WebinarLinkRules.isValidLink(teamsLink)
        else { return nil }
        return "Enter a valid meeting link starting with https://"
    }

    var startDateString: String? { startDate.map(format) }
    var endDateString: String? { endDate.map(format) }
    var registrationEndDateString: String? { registrationEndDate.map(format) }

    /// End date cannot be before the start date.
    var endDateMinimum: Date? { startDate.map(ScheduleDateRules.endMinimum(forStart:)) }

    /// Registration end date allowed window: [start - 3 days, start].
    var registrationMinimum: Date? { startDate.map { ScheduleDateRules.registrationWindow(forStart: $0).min } }
    var registrationMaximum: Date? { startDate.map { ScheduleDateRules.registrationWindow(forStart: $0).max } }

    var datesEnabled: Bool { true }
    var endAndRegEnabled: Bool { startDate != nil }

    /// Holidays only make sense when the range has a day between its locked start and end.
    var canSetHolidays: Bool { ScheduleDateRules.hasMarkableHolidays(start: startDate, end: endDate) }

    var holidaysSubtitle: String {
        guard canSetHolidays else { return "Available for schedules of 3 days or more" }
        let count = holidays.filter { $0.isHoliday }.count
        return count > 0 ? "\(count) holiday\(count > 1 ? "s" : "") marked" : "Schedule spans the selected range"
    }

    var canContinue: Bool {
        if isScheduleCodeEditable,
           scheduleCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        guard selectedCourse != nil, selectedModule != nil else { return false }
        if deliveryMode == .online, webinarType == nil { return false }
        // The hand-entered Teams link is required once the tenant unlocks it.
        if requiresTeamsLink, !WebinarLinkRules.isValidLink(teamsLink) { return false }
        guard startDate != nil, endDate != nil, registrationEndDate != nil else { return false }
        guard startTime != nil, endTime != nil else { return false }
        // Backstop for pairs that never went through the pickers — e.g. a draft hydrated
        // from an existing schedule in edit mode.
        guard !ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: startTime, end: endTime) else { return false }
        return true
    }

    func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = dateFormat
        f.locale = Locale.current
        return f.string(from: date)
    }

    func parse(_ string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = dateFormat
        f.locale = Locale.current
        return f.date(from: string)
    }
}

// MARK: - Actions
extension ScheduleBasicDetailsViewModel {

    func onCourseSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { courseResults = []; return }
        Task { [weak self] in await self?.fetchCourses(query: trimmed) }
    }

    func didSelectCourse(_ course: ScheduleBasicDetailsDataModel.Course) {
        selectedCourse = course
        selectedModule = nil
        modules = []
        Task { [weak self] in await self?.fetchModules(courseID: "\(course.id)") }
    }

    func didSelectModule(_ module: ScheduleBasicDetailsDataModel.ModuleItem) {
        selectedModule = module
    }

    func didSelectTimezone(_ timezone: ScheduleBasicDetailsDataModel.TimezoneItem) {
        selectedTimezone = timezone
    }

    func didSelectDelivery(_ mode: DeliveryMode) {
        deliveryMode = mode
        if mode == .offline {
            webinarType = nil
            credentials = nil
            selectedCredential = nil
            isCredentialRevealed = false
            // An offline schedule has no meeting at all.
            clearTeamsLink()
        }
    }

    func didSelectWebinarType(_ type: WebinarType) {
        guard type != webinarType else { return }
        webinarType = type
        credentials = nil
        selectedCredential = nil
        isCredentialRevealed = false
        clearTeamsLink()
        guard type.hasCredentialAPI else { return }
        Task { [weak self] in await self?.fetchCredential(for: type) }
    }

    func didSelectCredential(_ credential: ScheduleBasicDetailsDataModel.Credential) {
        selectedCredential = credential
        isCredentialRevealed = false
    }

    func toggleCredentialReveal() {
        isCredentialRevealed.toggle()
    }

    // MARK: Meeting link

    /// The model keeps the sanitized value so a hard-wrapped paste can never reach the
    /// payload; the field itself keeps whatever the user typed until it is remounted.
    func didEditTeamsLink(_ text: String) {
        teamsLink = WebinarLinkRules.normalizedLink(text)
    }

    /// A link belongs to the provider it was pasted for, so it does not survive a switch.
    private func clearTeamsLink() {
        teamsLink = ""
        linkFieldToken += 1
    }


    // MARK: Date selection
    func didSelectStartDate(_ string: String) {
        guard let date = parse(string) else { return }
        guard !isRefusedSunday(date) else { return }
        startDate = date
        // Auto-populate end & registration end with the start date.
        let populated = ScheduleDateRules.autoPopulated(forStart: date)
        endDate = populated.end
        registrationEndDate = populated.registrationEnd
        syncHolidaysForRange()
    }

    func didSelectEndDate(_ string: String) {
        guard let date = parse(string) else { return }
        guard !isRefusedSunday(date) else { return }
        guard let start = startDate else { endDate = date; syncHolidaysForRange(); return }
        let clamped = ScheduleDateRules.clampedEnd(date, start: start)
        endDate = clamped
        if clamped != date {
            toast = Toast(style: .warning, message: "End date cannot be before start date.")
        }
        syncHolidaysForRange()
    }

    func didSelectRegistrationEndDate(_ string: String) {
        guard let date = parse(string) else { return }
        guard !isRefusedSunday(date) else { return }
        registrationEndDate = date
    }

    /// Sundays are non-working days, so none of the three schedule dates may land on one.
    /// The calendar modal cannot grey out a single weekday, so the selection is refused
    /// here: the model keeps its previous value and the field is remounted from it.
    private func isRefusedSunday(_ date: Date) -> Bool {
        guard ScheduleDateRules.isSunday(date) else { return false }
        dateFieldToken += 1
        toast = Toast(style: .warning, message: "Sunday is not a working day. Please select another date.")
        return true
    }

    func didSelectStartTime(_ string: String) {
        startTime = ScheduleDateRules.canonical24HourTime(string) ?? string
        // A new start can strand an end time that was valid against the old one. Clear it
        // rather than silently keeping an out-of-order pair; the end field is keyed on
        // `startTime` in the view, so it visibly resets to its placeholder.
        if ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: startTime, end: endTime) {
            endTime = nil
            endTimeFieldToken += 1
            toast = Toast(style: .warning, message: "End time must be after start time. Please pick the end time again.")
        }
    }

    func didSelectEndTime(_ string: String) {
        let normalized = ScheduleDateRules.canonical24HourTime(string) ?? string
        guard !ScheduleDateRules.isEndTimeBeforeOrEqualToStart(start: startTime, end: normalized) else {
            endTimeFieldToken += 1
            toast = Toast(style: .warning, message: "End time must be later than start time.")
            return
        }
        endTime = normalized
    }

    // MARK: Holidays

    /// Keeps holiday rows aligned with the current range: a single-day schedule has no
    /// holidays at all, a wider range keeps in-range markings and drops stale rows.
    private func syncHolidaysForRange() {
        guard canSetHolidays, let start = startDate, let end = endDate else {
            holidays = []
            holidaysEnabled = false
            return
        }
        holidays = HolidayDay.generate(start: start, end: end, existing: holidays)
        holidaysEnabled = holidays.contains { $0.isHoliday }
    }

    func toggleHolidays(_ enabled: Bool) {
        guard canSetHolidays else { holidaysEnabled = false; return }
        holidaysEnabled = enabled
        if enabled { openHolidaysSheet() }
    }

    func openHolidaysSheet() {
        guard canSetHolidays else { return }
        guard let start = startDate, let end = endDate, start <= end else {
            toast = Toast(style: .warning, message: "Select start and end dates first.")
            holidaysEnabled = false
            return
        }
        let navModel = NavigationViewModel.HolidaysSheetNavModel(
            startDate: start,
            endDate: end,
            existing: holidays,
            onSave: { [weak self] updated in
                guard let self else { return }
                self.holidays = updated
                self.holidaysEnabled = !updated.filter { $0.isHoliday }.isEmpty
            }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.holidaysSheet(navModel))
    }

    // MARK: Footer
    func didTapBack() {
        commitToDraft()
        onBack()
    }

    func didTapContinue() {
        guard canContinue else {
            toast = Toast(style: .warning, message: "Please complete all required fields.")
            return
        }
        commitToDraft()
        onContinue()
    }

    private func commitToDraft() {
        draft.scheduleCode = isScheduleCodeEditable
            ? scheduleCode.trimmingCharacters(in: .whitespacesAndNewlines)
            : scheduleCode
        draft.course = selectedCourse
        draft.module = selectedModule
        draft.deliveryMode = deliveryMode
        draft.webinarType = webinarType
        // Keep the selected account first so it remains selected when this step is
        // recreated and so payload mapping has an unambiguous account to send.
        if let selectedCredential {
            draft.credential = [selectedCredential] + (credentials ?? []).filter { $0 != selectedCredential }
        } else {
            draft.credential = credentials
        }
        draft.timezone = selectedTimezone
        draft.startDate = startDate
        draft.endDate = endDate
        draft.registrationEndDate = registrationEndDate
        draft.startTime = startTime
        draft.endTime = endTime
        // Only ever carry a link the current provider can actually use.
        draft.teamsLink = requiresTeamsLink
            ? WebinarLinkRules.normalizedLink(teamsLink).isEmpty ? nil : WebinarLinkRules.normalizedLink(teamsLink)
            : nil
        draft.holidays = holidays
    }
}

// MARK: - API
extension ScheduleBasicDetailsViewModel {

    /// `ATPTLWCS` — unlocks the hand-entered Teams link. Mirrors the ASCFE fetch: silent on
    /// failure and fails closed, so a config outage hides the field rather than blocking
    /// the wizard or nagging the organiser.
    private func fetchTeamsLinkConfig() async {
        do {
            let response = try await ApiService.shared.requestGetHeader(
                type: ScheduleListDataModel.ConfigValueResponse.self,
                model: ScheduleListDataModel.GetConfigValueRequest(
                    key: TeamsLinkPolicy.configurationCode
                )
            )
            isTeamsStaticLinkEnabled = TeamsLinkPolicy.isEnabled(by: response)
        } catch {
            isTeamsStaticLinkEnabled = false
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    private func fetchScheduleCodeEditingConfig() async {
        do {
            let response = try await ApiService.shared.requestGetHeader(
                type: ScheduleListDataModel.ConfigValueResponse.self,
                model: ScheduleListDataModel.GetConfigValueRequest(
                    key: ScheduleCodeEditingPolicy.configurationCode
                )
            )
            isScheduleCodeEditable = ScheduleCodeEditingPolicy.isEnabled(by: response)
        } catch {
            // Configuration-backed permissions fail closed; generated schedule codes remain locked.
            isScheduleCodeEditable = false
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    private func fetchScheduleCode() async {
        do {
            let code = try await ApiService.shared.requestGetHeader(
                type: String.self,
                model: ScheduleBasicDetailsDataModel.ScheduleCodeRequest()
            )
            scheduleCode = code
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }

    private func fetchCourses(query: String) async {
        do {
            let results = try await ApiService.shared.requestGetHeader(
                type: [ScheduleBasicDetailsDataModel.Course].self,
                model: ScheduleBasicDetailsDataModel.CourseTypeAheadRequest(query: query)
            )
            courseResults = results
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: false)
        }
    }

    private func fetchModules(courseID: String) async {
        loadingState = .loading(message: "Loading modules...")
        do {
            let results = try await ApiService.shared.requestGetHeader(
                type: [ScheduleBasicDetailsDataModel.ModuleItem].self,
                model: ScheduleBasicDetailsDataModel.ModulesByCourseRequest(courseID: courseID)
            )
            modules = results
            deliveryMode = results.first?.type?.lowercased() == "vilt" ? .online : .offline
            loadingState = .none
            if results.isEmpty {
                toast = Toast(style: .info, message: "No modules found for this course.")
            }
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }

    private func fetchTimezones() async {
        do {
            let results = try await ApiService.shared.requestGetHeader(
                type: [ScheduleBasicDetailsDataModel.TimezoneItem].self,
                model: ScheduleBasicDetailsDataModel.TimezonesRequest()
            )
            timezones = results
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: false)
        }
    }

    private func fetchCredential(for type: WebinarType) async {
        let endpointName: String
        let defaultEndPointName: String
        switch type {
        case .zoom:
            endpointName = "GetZoomCred"
            defaultEndPointName = "GetDefaultzoomCred"

        case .teams:
            endpointName = "GetTeamsCred"
            defaultEndPointName = "GetDefaultTeamsCred"

        case .googleMeet:
            endpointName = "GetGsuitCred"
            defaultEndPointName = "GetDefaultGsuitCred"
        case .gotoMeeting: return
        }
        loadingState = .loading(message: "Fetching credentials...")
        do {
            async let cred = try? ApiService.shared.requestGetHeader(
                type: ScheduleBasicDetailsDataModel.Credential.self,
                model: ScheduleBasicDetailsDataModel.CredentialRequest(endpointName: endpointName)
            )

            async let defaultCred = ApiService.shared.requestGetHeader(
                type: [ScheduleBasicDetailsDataModel.Credential].self,
                model: ScheduleBasicDetailsDataModel.CredentialRequest(endpointName: defaultEndPointName)
            )

            let (credentialResult, defaultCredentialResult) = try await (cred, defaultCred)
            let results = [credentialResult].compactMap { $0 } + defaultCredentialResult
            credentials = results
            selectedCredential = results.first
            loadingState = .loaded
        } catch {
            switch error {
            case let apiError as APIError where apiError == .noData:
                loadingState = .none
                return
            case let apiError as APIError:
                handleAPIError(apiError.toUIError(), resetLoadingState: true, showToast: true)
            default:
                handleAPIError(error, resetLoadingState: true, showToast: true)
            }
        }
    }
}
