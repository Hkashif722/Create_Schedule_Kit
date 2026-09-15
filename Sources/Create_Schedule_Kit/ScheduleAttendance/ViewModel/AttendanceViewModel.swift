//
//  AttendanceViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the "Update Attendance" screen: the schedule's read-only details, the attendance
//  date (which may be locked to the current date), and the four ways to act on it — Scan QR,
//  Bulk mark, Download, and the read-only Attendees list.
//
//  This screen owns the date and nothing else. Marking happens on the screens it opens, each
//  of which receives the picked date, so a save can never disagree with the day chosen here.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class AttendanceViewModel: BaseViewModel {

    // MARK: - Dependencies
    let navModel: NavigationViewModel.AttendanceNavModel

    // MARK: - Screen state
    @Published var selectedDate: Date?
    @Published private(set) var restrictToCurrentDate: Bool = false
    @Published private(set) var totalUsersCount: Int = 0

    /// The schedule's own date range, fetched from `GetScheduleDetailsByID`. Bounds the
    /// attendance date picker; `nil` until the call lands (or if it fails).
    @Published private(set) var scheduleStartDate: Date?
    @Published private(set) var scheduleEndDate: Date?

    private var hasLoaded = false

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.AttendanceNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived UI state
extension AttendanceViewModel {

    var attendeesCountText: String { totalUsersCount > 0 ? "\(totalUsersCount)" : "" }

    /// Selectable window for the attendance date: the schedule's range, narrowed to today
    /// when attendance is locked to the current date.
    private var dateBounds: (min: Date?, max: Date?) {
        AttendanceDateRules.bounds(
            scheduleStart: scheduleStartDate,
            scheduleEnd: scheduleEndDate,
            restrictToCurrentDate: restrictToCurrentDate
        )
    }

    var datePickerMinimum: Date? { dateBounds.min }
    var datePickerMaximum: Date? { dateBounds.max }

    /// Range shown in the read-only "Schedule Details" field. Uses the fetched dates once
    /// available so the displayed range and the enforced bounds always agree; falls back to
    /// the string the schedule card passed in.
    var scheduleDateRangeText: String {
        let start = scheduleStartDate.map(Self.mediumDateFormatter.string(from:)) ?? ""
        let end = scheduleEndDate.map(Self.mediumDateFormatter.string(from:)) ?? ""
        if start.isEmpty && end.isEmpty { return navModel.dateRangeText }
        if start.isEmpty { return end }
        if end.isEmpty || end == start { return start }
        return "\(start) – \(end)"
    }
}

// MARK: - Lifecycle / loading
extension AttendanceViewModel {

    func onAppear() {
        // The count is refreshed on every appearance, so returning from a save or a delete
        // shows the new total; the heavier one-time fetches stay behind the latch.
        Task { [weak self] in await self?.fetchUsersCount() }

        guard !hasLoaded else { return }
        hasLoaded = true
        Task { [weak self] in await self?.loadEverything() }
    }

    @MainActor
    private func loadEverything() async {
        loadingState = .loading(title: "Loading attendance", message: "Please wait.")

        // The two calls that bound the date picker are independent of each other.
        async let currentDate: Void = fetchCurrentDateFlag()
        async let scheduleDates: Void = fetchScheduleDates()
        _ = await (currentDate, scheduleDates)
        loadingState = .none
    }
}

// MARK: - Date selection
extension AttendanceViewModel {

    /// The calendar modal already refuses out-of-range days; this is a defensive backstop so
    /// an out-of-range date can never reach a save payload.
    func didSelectDate(_ date: Date) {
        let bounds = dateBounds
        guard AttendanceDateRules.isSelectable(date, min: bounds.min, max: bounds.max) else {
            toast = Toast(style: .warning, message: Self.outOfRangeMessage)
            return
        }
        selectedDate = date
    }

    /// The schedule range and the current-date flag arrive in parallel with the rest of the
    /// screen, so a date can be picked before the bounds are known. Drop it once they narrow
    /// past the selection — otherwise a save would submit an out-of-range attendance date.
    @MainActor
    private func discardSelectedDateIfOutOfBounds() {
        guard let date = selectedDate else { return }
        let bounds = dateBounds
        guard !AttendanceDateRules.isSelectable(date, min: bounds.min, max: bounds.max) else { return }
        selectedDate = nil
        toast = Toast(style: .warning, message: Self.outOfRangeMessage)
    }

    private static let outOfRangeMessage =
        "Please select a date within the schedule's date range."
}

// MARK: - Actions
extension AttendanceViewModel {

    /// Marking anyone needs the day first, so all three marking actions refuse without it.
    /// `nil` when the action is safe to open.
    var markBlockReason: String? {
        selectedDate == nil ? "Please select the attendance date." : nil
    }

    func didTapScanQR() {
        guard requireDate(), let date = selectedDate else { return }

        let scannerNavModel = NavigationViewModel.AttendanceQRScannerNavModel(
            scheduleID: navModel.scheduleID,
            courseID: navModel.courseID,
            moduleID: navModel.moduleID,
            courseName: navModel.courseName,
            attendanceDate: date,
            onMarked: { [weak self] in
                Task { await self?.fetchUsersCount() }
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.attendanceQRScanner(scannerNavModel)
        )
    }

    func didTapBulkMark() {
        guard requireDate() else { return }
        openUsers(mode: .bulkMark)
    }

    func didTapDownload() {
        guard requireDate(), let date = selectedDate else { return }

        let codeNavModel = NavigationViewModel.ScheduleQRCodeNavModel(
            scheduleID: navModel.scheduleID,
            courseID: navModel.courseID,
            moduleID: navModel.moduleID,
            courseName: navModel.courseName,
            scheduleCode: navModel.scheduleCode,
            attendanceDate: date
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.scheduleQRCode(codeNavModel)
        )
    }

    /// The read-only list is about who is on the schedule rather than about a particular
    /// day, so it opens without a date.
    func didTapAttendees() {
        openUsers(mode: .attendees)
    }

    func didTapBack() {
        Task { @MainActor [weak self] in self?.router.dismissScreen() }
    }

    private func requireDate() -> Bool {
        guard let message = markBlockReason else { return true }
        toast = Toast(style: .warning, message: message)
        return false
    }

    private func openUsers(mode: AttendanceUsersMode) {
        let usersNavModel = NavigationViewModel.AttendanceUsersNavModel(
            mode: mode,
            scheduleID: navModel.scheduleID,
            courseID: navModel.courseID,
            moduleID: navModel.moduleID,
            scheduleCode: navModel.scheduleCode,
            attendanceDate: selectedDate,
            onAttendanceChanged: { [weak self] in
                Task { await self?.fetchUsersCount() }
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.attendanceUsers(usersNavModel)
        )
    }
}

// MARK: - API
extension AttendanceViewModel {

    @MainActor
    private func fetchUsersCount() async {
        do {
            totalUsersCount = try await ApiService.shared.requestPostHeader(
                type: Int.self,
                model: AttendanceDataModel.GetUsersCountForAttendanceRequest(),
                payload: AttendanceDataModel.UsersPayload(
                    scheduleID: navModel.scheduleID,
                    courseId: navModel.courseID,
                    moduleId: 0,
                    page: 1,
                    pageSize: 10,
                    searchText: nil,
                    search1: nil,
                    searchText1: nil,
                    type: "Attandance"
                )
            )
        } catch {
            if let apiError = error as? APIError, case .noData = apiError {
                totalUsersCount = 0
            } else {
                // Silent: the count is a subtitle, not this screen's purpose.
                handleAPIError(error, resetLoadingState: false, showToast: false)
            }
        }
    }

    @MainActor
    private func fetchCurrentDateFlag() async {
        do {
            // This endpoint returns a bare plain-text body (`Yes`/`No`), not JSON, so it must
            // bypass ApiService's JSONDecoder — see PlainTextAPIClient.
            let flag = try await PlainTextAPIClient.get(AttendanceDataModel.GetAttendanceOnCurrentDateRequest())
            restrictToCurrentDate = flag.lowercased() == "yes"
            discardSelectedDateIfOutOfBounds()
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    /// Fetches the schedule so the attendance date picker can be bounded to its own
    /// [startDate, endDate] range. Reuses the edit flow's endpoint and DTO.
    @MainActor
    private func fetchScheduleDates() async {
        do {
            let details = try await ApiService.shared.requestPostHeader(
                type: EditScheduleDataModel.ScheduleDetailsResponse.self,
                model: EditScheduleDataModel.GetScheduleDetailsByIDRequest(),
                payload: EditScheduleDataModel.GetScheduleDetailsByIDRequest.Payload(
                    scheduleId: navModel.scheduleID
                )
            )
            scheduleStartDate = ScheduleDraft.parseAPIDate(details.startDate)
            scheduleEndDate = ScheduleDraft.parseAPIDate(details.endDate)
            discardSelectedDateIfOutOfBounds()
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }
}

// MARK: - Date formatting
private extension AttendanceViewModel {

    /// `Jul 02, 2026` — matches `ScheduleListDataModel.Schedule.dateRangeText`, so the info
    /// card reads the same whether the range comes from the card or the fetched schedule.
    static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f
    }()
}
