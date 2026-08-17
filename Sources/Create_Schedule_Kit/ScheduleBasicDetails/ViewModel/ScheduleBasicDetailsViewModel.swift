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
    /// Edit mode locks the schedule-identity fields (course, module, delivery, webinar).
    let isEditMode: Bool
    private let onBack: () -> Void
    private let onContinue: () -> Void

    // MARK: - Published State
    @Published var scheduleCode: String = ""
    @Published var courseResults: [ScheduleBasicDetailsDataModel.Course] = []
    @Published var selectedCourse: ScheduleBasicDetailsDataModel.Course?
    @Published var modules: [ScheduleBasicDetailsDataModel.ModuleItem] = []
    @Published var selectedModule: ScheduleBasicDetailsDataModel.ModuleItem?

    @Published var deliveryMode: DeliveryMode = .online
    @Published var webinarType: WebinarType?
    @Published var credential: ScheduleBasicDetailsDataModel.Credential?
    @Published var isCredentialRevealed: Bool = false

    @Published var timezones: [ScheduleBasicDetailsDataModel.TimezoneItem] = []
    @Published var selectedTimezone: ScheduleBasicDetailsDataModel.TimezoneItem?

    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var registrationEndDate: Date?
    @Published var startTime: String?
    @Published var endTime: String?

    @Published var holidaysEnabled: Bool = false
    @Published var holidays: [HolidayDay] = []

    private let dateFormat = CreateScheduleKitAPIManager.shared.getConfiguaredDate

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
        credential = draft.credential
        selectedTimezone = draft.timezone
        startDate = draft.startDate
        endDate = draft.endDate
        registrationEndDate = draft.registrationEndDate
        startTime = draft.startTime
        endTime = draft.endTime
        holidays = draft.holidays
        holidaysEnabled = !draft.holidays.filter { $0.isHoliday }.isEmpty
    }
}

// MARK: - Derived UI State
extension ScheduleBasicDetailsViewModel {

    var showWebinarSection: Bool { deliveryMode == .online }

    var showCredentialSection: Bool {
        showWebinarSection && (webinarType?.hasCredentialAPI ?? false) && credential != nil
    }

    var webinarOptions: [WebinarType] { WebinarType.allCases }

    var deliveryOptions: [DeliveryMode] { DeliveryMode.allCases }

    // Read-only category rows shown in edit mode (from the locked module).
    var categoryText: String { selectedModule?.category ?? "" }
    var subCategoryText: String { selectedModule?.subCategory ?? "" }
    var subSubCategoryText: String { selectedModule?.subSubCategory ?? "" }

    /// The credential identity (email) — decrypted when revealed, masked otherwise.
    var credentialDisplayValue: String {
        guard let raw = credential?.teamsEmail, !raw.isEmpty else { return "—" }
        guard isCredentialRevealed else { return String(repeating: "•", count: min(raw.count, 12)) }
        let decrypted = EncryptDecryptUtility.shared.newDecryptString(responseStr: raw)
        return decrypted.isEmpty ? raw : decrypted
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

    var holidaysSubtitle: String {
        let count = holidays.filter { $0.isHoliday }.count
        return count > 0 ? "\(count) holiday\(count > 1 ? "s" : "") marked" : "Schedule spans the selected range"
    }

    var canContinue: Bool {
        guard selectedCourse != nil, selectedModule != nil else { return false }
        if deliveryMode == .online, webinarType == nil { return false }
        guard startDate != nil, endDate != nil, registrationEndDate != nil else { return false }
        guard startTime != nil, endTime != nil else { return false }
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

    func didSelectDelivery(_ mode: DeliveryMode) {
        deliveryMode = mode
        if mode == .offline {
            webinarType = nil
            credential = nil
            isCredentialRevealed = false
        }
    }

    func didSelectWebinarType(_ type: WebinarType) {
        webinarType = type
        credential = nil
        isCredentialRevealed = false
        guard type.hasCredentialAPI else { return }
        Task { [weak self] in await self?.fetchCredential(for: type) }
    }

    func toggleCredentialReveal() {
        isCredentialRevealed.toggle()
    }

    // MARK: Date selection
    func didSelectStartDate(_ string: String) {
        guard let date = parse(string) else { return }
        startDate = date
        // Auto-populate end & registration end with the start date.
        let populated = ScheduleDateRules.autoPopulated(forStart: date)
        endDate = populated.end
        registrationEndDate = populated.registrationEnd
    }

    func didSelectEndDate(_ string: String) {
        guard let date = parse(string) else { return }
        guard let start = startDate else { endDate = date; return }
        let clamped = ScheduleDateRules.clampedEnd(date, start: start)
        endDate = clamped
        if clamped != date {
            toast = Toast(style: .warning, message: "End date cannot be before start date.")
        }
    }

    func didSelectRegistrationEndDate(_ string: String) {
        guard let date = parse(string) else { return }
        registrationEndDate = date
    }

    func didSelectStartTime(_ string: String) { startTime = string }
    func didSelectEndTime(_ string: String) { endTime = string }

    // MARK: Holidays
    func toggleHolidays(_ enabled: Bool) {
        holidaysEnabled = enabled
        if enabled { openHolidaysSheet() }
    }

    func openHolidaysSheet() {
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
        draft.scheduleCode = scheduleCode
        draft.course = selectedCourse
        draft.module = selectedModule
        draft.deliveryMode = deliveryMode
        draft.webinarType = webinarType
        draft.credential = credential
        draft.timezone = selectedTimezone
        draft.startDate = startDate
        draft.endDate = endDate
        draft.registrationEndDate = registrationEndDate
        draft.startTime = startTime
        draft.endTime = endTime
        draft.holidays = holidays
    }
}

// MARK: - API
extension ScheduleBasicDetailsViewModel {

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
        switch type {
        case .zoom:        endpointName = "GetZoomCred"
        case .teams:       endpointName = "GetTeamsCred"
        case .googleMeet:  endpointName = "GetGsuitCred"
        case .gotoMeeting: return
        }
        loadingState = .loading(message: "Fetching credentials...")
        do {
            let cred = try await ApiService.shared.requestGetHeader(
                type: ScheduleBasicDetailsDataModel.Credential.self,
                model: ScheduleBasicDetailsDataModel.CredentialRequest(endpointName: endpointName)
            )
            credential = cred
            loadingState = .none
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }
}
