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

    func selectTab(_ tab: AttendanceTab) { activeTab = tab }

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

    // No endpoint provided yet for this row action.
    func didTapViewUser(_ user: User) { /* TODO: attendance user detail */ }

    func didTapDeleteUser(_ user: User) {
        confirmDelete { [weak self] in
            Task { await self?.deleteAttendance(user) }
        }
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
            // Non-fatal: without the range the picker keeps its previous behaviour rather
            // than blocking the screen, and the info card falls back to the passed-in text.
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
            canDelete = (response.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "yes"
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    @MainActor
    private func submitAttendance() async {
        guard let date = selectedDate else { return }
        let statusCode = selectedStatus?.valueCode ?? "ATTD"
        let dateString = Self.isoFormatter.string(from: date)

        let items = selectedUsers.values.map { user in
            AttendanceDataModel.UpdateItem(
                id: 0,
                isPresent: statusCode == "ATTD",
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
                model: AttendanceDataModel.UpdateAttendanceRequest(),
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

    /// API date format: `2026-06-30T00:00:00`.
    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// `Jul 02, 2026` — matches `ScheduleListDataModel.Schedule.dateRangeText`, so the info
    /// card reads the same whether the range comes from the card or the fetched schedule.
    static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f
    }()
}
