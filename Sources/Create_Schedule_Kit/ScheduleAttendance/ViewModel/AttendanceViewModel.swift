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

import Foundation
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

    func isSelected(_ user: User) -> Bool { selectedUsers[user.id] != nil }

    /// When attendance is locked to today, clamp the date picker to the current day only.
    var datePickerMinimum: Date? { restrictToCurrentDate ? Date() : nil }
    var datePickerMaximum: Date? { restrictToCurrentDate ? Date() : nil }
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

        // Config + count are independent of the list → run everything in parallel.
        async let status: Void = fetchStatusOptions()
        async let currentDate: Void = fetchCurrentDateFlag()
        async let deleteFlag: Void = fetchDeleteFlag()
        async let count: Void = fetchUsersCount()
        await loadInitial()
        _ = await (status, currentDate, deleteFlag, count)
    }
}

// MARK: - Selection & tabs
extension AttendanceViewModel {

    func selectTab(_ tab: AttendanceTab) { activeTab = tab }

    func selectStatus(_ option: StatusOption) { selectedStatus = option }

    func didSelectDate(_ date: Date) {
        selectedDate = date
    }

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

    // No endpoints provided yet for these row actions.
    func didTapViewUser(_ user: User) { /* TODO: attendance user detail */ }
    func didTapDeleteUser(_ user: User) { /* TODO: delete attendance (endpoint pending) */ }
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
            moduleId: navModel.moduleID,
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
            handleAPIError(error, resetLoadingState: false, showToast: false)
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
}
