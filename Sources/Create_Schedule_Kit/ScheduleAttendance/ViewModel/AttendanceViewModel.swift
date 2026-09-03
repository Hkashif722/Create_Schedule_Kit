//
//  AttendanceViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the "Update Attendance" screen: a paginated user list (with count fetched in
//  parallel), an attendance-status dropdown, a date field that may be locked to the current
//  date, multi-selection, and a Save that marks attendance for the selected users.
//
//  Modeled on `NominateUsersViewModel` (the closest analog). Pagination is handled by
//  `PaginatableViewModel`; independent config/count calls run in parallel with the first page.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

enum AttendanceTab: CaseIterable {
    case attendance
    case nominate

    var title: String {
        switch self {
        case .attendance: return "Attendance"
        case .nominate:   return "Nominate"
        }
    }
}

final class AttendanceViewModel: BaseViewModel, PaginatableViewModel {

    typealias User = AttendanceDataModel.AttendanceUser
    typealias StatusOption = AttendanceDataModel.AttendanceStatusOption

    /// Selectable page sizes for the "Show" dropdown.
    static let pageSizeChoices = [10, 25, 50, 100]

    // MARK: - Dependencies
    let navModel: NavigationViewModel.AttendanceNavModel

    // MARK: - PaginatableViewModel state
    @Published var items: [User] = []
    override var itemsPerPage: Int { pageSize }

    // MARK: - Screen state
    @Published var activeTab: AttendanceTab = .attendance
    @Published var statusOptions: [StatusOption] = []
    @Published var selectedStatus: StatusOption?
    @Published var selectedDate: Date?
    @Published var pageSize: Int = 10
    @Published private(set) var selectedUsers: [Int: User] = [:]
    @Published private(set) var totalUsersCount: Int = 0
    @Published private(set) var restrictToCurrentDate: Bool = false
    @Published private(set) var canDelete: Bool = false

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

    var totalText: String { "Total: \(totalUsersCount)" }
    var selectedText: String { "Selected: \(selectedUsers.count)" }
    var isAllSelected: Bool { !items.isEmpty && items.allSatisfy { selectedUsers[$0.id] != nil } }
    var isSaveEnabled: Bool { selectedDate != nil && !selectedUsers.isEmpty }

    /// Save belongs to the Attendance tab only — the embedded Nominate tab brings its
    /// own Cancel / Nominate footer.
    var showsSaveFooter: Bool { activeTab == .attendance }

    /// An external trainer marks attendance but cannot nominate, so the Nominate tab is not
    /// offered at all — leaving a single tab, which the bar then hides entirely.
    var availableTabs: [AttendanceTab] {
        permissions.canNominate ? AttendanceTab.allCases : [.attendance]
    }

    func isSelected(_ user: User) -> Bool { selectedUsers[user.id] != nil }

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
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { [weak self] in await self?.loadEverything() }
    }

    @MainActor
    private func loadEverything() async {
        loadingState = .loading(title: "Loading attendance", message: "Please wait.")

        // Config + count + schedule dates are independent of the list → run in parallel.
        async let status: Void = fetchStatusOptions()
        async let currentDate: Void = fetchCurrentDateFlag()
        async let deleteFlag: Void = fetchDeleteFlag()
        async let count: Void = fetchUsersCount()
        async let scheduleDates: Void = fetchScheduleDates()
        await loadInitial()
        _ = await (status, currentDate, deleteFlag, count, scheduleDates)
    }
}

// MARK: - Selection & tabs
extension AttendanceViewModel {

    func selectTab(_ tab: AttendanceTab) {
        // Role first: a tab this role cannot reach is refused silently, not explained with a
        // "pick a date" toast that implies it would otherwise open.
        guard availableTabs.contains(tab) else { return }
        if tab == .nominate, let message = nominateBlockReason {
            toast = Toast(style: .warning, message: message)
            return
        }
        activeTab = tab
    }

    /// Nominating from this screen inserts attendance rows directly rather than creating a
    /// nomination, so the date and status must be chosen before the tab can be opened.
    /// `nil` when the tab is safe to open.
    var nominateBlockReason: String? {
        if selectedDate == nil { return "Please select the attendance date." }
        if (selectedStatus?.valueCode ?? "").isEmpty { return "Please select the attendance status." }
        return nil
    }

    /// Called after users are inserted from the Nominate tab so the list and count catch up.
    func reloadAfterNomination() {
        Task { [weak self] in
            guard let self else { return }
            async let count: Void = fetchUsersCount()
            await loadInitial()
            _ = await count
        }
    }

    func selectStatus(_ option: StatusOption) { selectedStatus = option }

    /// The calendar modal already refuses out-of-range days; this is a defensive backstop so
    /// an out-of-range date can never reach the save payload.
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
    /// past the selection — otherwise Save would submit an out-of-range attendance date.
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

    func changePageSize(_ size: Int) {
        guard size != pageSize else { return }
        pageSize = size
        Task { [weak self] in
            await self?.fetchUsersCount()
            await self?.loadInitial()
        }
    }

    func toggle(_ user: User) {
        if selectedUsers[user.id] != nil {
            selectedUsers.removeValue(forKey: user.id)
        } else {
            selectedUsers[user.id] = user
        }
    }

    func toggleSelectAll() {
        if isAllSelected {
            items.forEach { selectedUsers.removeValue(forKey: $0.id) }
        } else {
            items.forEach { selectedUsers[$0.id] = $0 }
        }
    }

    func loadMoreIfNeeded(currentItem: User) {
        guard shouldLoadMore(currentItem: currentItem) else { return }
        Task { [weak self] in await self?.loadMore() }
    }
}

// MARK: - Actions
extension AttendanceViewModel {

    func didTapSave() {
        guard selectedDate != nil else {
            toast = Toast(style: .warning, message: "Please select the attendance date.")
            return
        }
        guard !selectedUsers.isEmpty else {
            toast = Toast(style: .warning, message: "Please select at least one user.")
            return
        }
        Task { [weak self] in await self?.submitAttendance() }
    }

    /// Eye button — opens the "User Attendance Details" popup with that user's attendance
    /// history for this schedule.
    func didTapViewUser(_ user: User) {
        Task { [weak self] in await self?.fetchUserAttendanceDetails(user) }
    }

    func didTapDeleteUser(_ user: User) {
        guard user.hasOverAllStatus else {
            showMissingStatusAlert()
            return
        }
        confirmDelete { [weak self] in
            Task { await self?.deleteAttendance(user) }
        }
    }

    /// Delete acts on the tapped row, but the copy is pluralized off the current selection so
    /// it reads correctly when the user has several rows checked.
    var missingStatusMessage: String {
        selectedUsers.count > 1
            ? "Cannot delete attendance for the selected users as attendance statuses are not present."
            : "Cannot delete attendance for the selected user as attendance status is not present."
    }

    /// A row with no overall status has nothing to remove, so the delete never reaches the API.
    @MainActor
    private func showMissingStatusAlert() {
        let message = missingStatusMessage
        let model = CustomAlertPopupModel(
            title: "Delete",
            alertType: .warning,
            content: {
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding()
            },
            primaryButtonTitle: "OK",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.customAlertPopupView(model))
        )
    }

    /// Read-only detail popup for one user's attendance records. `CustomAlertPopupModel` captures
    /// its content as an `AnyView` at construction, so the rows must already be in hand — the
    /// fetch happens first, behind the screen's loading overlay.
    @MainActor
    private func showUserAttendanceDetails(_ details: [AttendanceDataModel.UserAttendanceDetail]) {
        let model = CustomAlertPopupModel(
            title: "User Attendance Details",
            alertType: .none,
            content: {
                UserAttendanceDetailsPopupContent(details: details)
            },
            primaryButtonTitle: "Close",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.customAlertPopupView(model))
        )
    }

    /// Destructive-action confirmation, mirroring the web dialog.
    @MainActor
    private func confirmDelete(onConfirm: @escaping () -> Void) {
        let model = CustomAlertPopupModel(
            title: "Delete",
            alertType: .none,
            content: {
                Text("Do you want to delete selected record permanently?")
                    .multilineTextAlignment(.center)
                    .padding()
            },
            primaryButtonTitle: "Delete",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
                onConfirm()
            },
            secondaryButtonTitle: "Cancel",
            secondaryAction: { [weak self] in
                self?.router.dismissModal()
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.customAlertPopupView(model))
        )
    }
}

// MARK: - PaginatableViewModel
extension AttendanceViewModel {

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [User] {
        try await ApiService.shared.requestPostHeader(
            type: [User].self,
            model: AttendanceDataModel.GetUsersForAttendanceRequest(),
            payload: usersPayload(page: pageIndex)
        )
    }

    func handleFetchError(_ error: Error, isLoadingMore: Bool) {
        if let apiError = error as? APIError, case .noData = apiError {
            hasMore = false

            if !isLoadingMore {
                loadingState = .loaded
                emptyState = .noData
                toast = Toast(style: .info, message: "No nominated users found.")
            }
            return
        }

        if !isLoadingMore {
            loadingState = .none
            emptyState = .error
        }

        handleAPIError(error, resetLoadingState: false, showToast: true)
    }
}

// MARK: - API
extension AttendanceViewModel {

    private func usersPayload(page: Int) -> AttendanceDataModel.UsersPayload {
        AttendanceDataModel.UsersPayload(
            scheduleID: navModel.scheduleID,
            courseId: navModel.courseID,
            moduleId: 0,
            page: page,
            pageSize: pageSize,
            searchText: nil,
            search1: nil,
            searchText1: nil,
            type: "Attandance"
        )
    }

    @MainActor
    private func fetchUsersCount() async {
        do {
            totalUsersCount = try await ApiService.shared.requestPostHeader(
                type: Int.self,
                model: AttendanceDataModel.GetUsersCountForAttendanceRequest(),
                payload: usersPayload(page: 1)
            )
        } catch {
            if let apiError = error as? APIError, case .noData = apiError {
                // Deleted — fall through to the success path.
            } else {
                handleAPIError(error, resetLoadingState: true, showToast: true)
            }
        }
    }

    @MainActor
    private func fetchStatusOptions() async {
        do {
            let options = try await ApiService.shared.requestGetHeader(
                type: [StatusOption].self,
                model: AttendanceDataModel.GetAttendanceStatusRequest()
            )
            statusOptions = options.filter { $0.isDeleted != true }
            // Default to the first option (typically "Attended") so Save has a status.
            selectedStatus = selectedStatus ?? statusOptions.first
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
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

    @MainActor
    private func fetchDeleteFlag() async {
        do {
            let response = try await ApiService.shared.requestGetHeader(
                type: ScheduleListDataModel.ConfigValueResponse.self,
                model: ScheduleListDataModel.GetConfigValueRequest(key: "ATTNOM_DEL")
            )
            canDelete = response.isYes
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    /// Saves the marked attendance to the bare `ILTTrainingAttendance` endpoint as an array of
    /// `MarkAttendanceItem`, reproducing the web client's save payload field for field.
    ///
    /// Two details are load-bearing and deliberately differ from the Nominate tab's
    /// `InsertItem`, which posts to the same route:
    ///  • the date is zone-less (`isoDayStartString`). With a trailing `Z` the server reads it
    ///    as UTC, shifts it to its own local time, fails to match the user's existing row and
    ///    rejects the save as "Attendance for the user already exists."
    ///  • `isPresent` follows `AttendanceDataModel.isPresent(forStatusCode:)` — true for
    ///    Attended and Absent, false for Withdrew and Waived. That matches the web client,
    ///    which sends `IsPresent: true` for Absent. See that method for the full table.
    @MainActor
    private func submitAttendance() async {
        guard let date = selectedDate else { return }
        let statusCode = selectedStatus?.valueCode ?? AttendanceDataModel.StatusCode.attended
        let dateString = date.isoDayStartString

        let items = selectedUsers.values.map { user in
            AttendanceDataModel.MarkAttendanceItem(
                id: 0,
                isPresent: AttendanceDataModel.isPresent(forStatusCode: statusCode),
                userId: user.id,
                moduleId: navModel.moduleID,
                scheduleId: navModel.scheduleID,
                courseId: navModel.courseID,
                isweb: true,
                attendanceStatus: statusCode,
                attendanceDate: dateString,
                withdrewReason: nil,
                withdrewRemark: nil
            )
        }

        loadingState = .loading(title: "Saving attendance", message: "Please wait.")
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: NominateUsersDataModel.NominateResponse.self,
                model: AttendanceDataModel.InsertAttendanceRequest(),
                payload: items
            )
            loadingState = .none
            toast = Toast(style: .success, message: response.description ?? "Attendance saved successfully.")
            selectedUsers.removeAll()
            await fetchUsersCount()
            await refresh()
        }catch let error as APIError {
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
        }  catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }

    /// Fetches one user's attendance history for the eye-button popup. `courseId`/`moduleId` come
    /// from `navModel` (as in `submitAttendance`) rather than from `usersPayload`, which sends
    /// `moduleId: 0` for the list call.
    @MainActor
    private func fetchUserAttendanceDetails(_ user: User) async {
        loadingState = .loading(title: "Loading details", message: "Please wait.")
        do {
            let details = try await ApiService.shared.requestPostHeader(
                type: [AttendanceDataModel.UserAttendanceDetail].self,
                model: AttendanceDataModel.GetDetailsForUserAttendanceRequest(),
                payload: AttendanceDataModel.UserAttendanceDetailPayload(
                    scheduleID: navModel.scheduleID,
                    courseId: navModel.courseID,
                    moduleId: navModel.moduleID,
                    userId: user.id
                )
            )
            loadingState = .none
            showUserAttendanceDetails(details)
        } catch let error as APIError {
            // A user with no marked attendance answers `noData` rather than an empty array —
            // show the empty popup instead of an error toast (same tolerance as `fetchUsersCount`).
            if case .noData = error {
                loadingState = .none
                showUserAttendanceDetails([])
                return
            }
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }

    /// Removes a user's attendance record. The server answers with a bare `true`/`false`.
    @MainActor
    private func deleteAttendance(_ user: User) async {
        loadingState = .loading(title: "Deleting", message: "Please wait.")
        do {
            let didDelete = try await ApiService.shared.requestPostHeader(
                type: Bool.self,
                model: AttendanceDataModel.AttendanceDeleteRequest(),
                payload: AttendanceDataModel.AttendanceDeletePayload(
                    userMasterId: user.id,
                    scheduleId: navModel.scheduleID
                )
            )
            loadingState = .none
            guard didDelete else {
                toast = Toast(style: .error, message: "Could not delete this record.")
                return
            }
            toast = Toast(style: .success, message: "Record deleted successfully.")
            selectedUsers.removeValue(forKey: user.id)
            await fetchUsersCount()
            await refresh()
        } catch let error as APIError {
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
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
