//
//  NominateUsersViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the post-create "Nominate Users" sheet: resolves the numeric scheduleID,
//  loads the paginated user list, powers the column-scoped search typeahead, tracks
//  multi-selection, and submits nominations.
//
//  Load is optimized: independent calls (batchwise flag, search columns, schedule
//  context) run in parallel; once scheduleID is known, the user count and first page
//  are fetched in parallel too. Pagination is handled by `PaginatableViewModel`.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class NominateUsersViewModel: BaseViewModel, PaginatableViewModel {

    typealias User = NominateUsersDataModel.NominationUser
    typealias Column = NominateUsersDataModel.AccessibilityColumn

    // MARK: - Dependencies
    private let navModel: NavigationViewModel.NominateUsersNavModel
    private var courseId: Int { navModel.courseID }
    /// Non-nil only when embedded in Update Attendance. Read through the closure each time
    /// so the date/status reflect the Attendance tab's current selection.
    private var attendanceContext: NavigationViewModel.NominateAttendanceContext? {
        navModel.attendanceContext?()
    }
    private let searchDebouncer = Debouncer<String>(interval: 0.3)

    // MARK: - PaginatableViewModel state
    @Published var items: [User] = []

    // MARK: - Screen state
    @Published var columns: [Column] = []
    @Published var selectedColumn: Column?
    @Published var searchText: String = ""
    @Published var typeaheadResults: [NominateUsersDataModel.TypeAheadResult] = []
    /// The suggestion currently shown in the search field. Owned here rather than left to
    /// the dropdown's internal state so it can be cleared when the filter parameter changes.
    @Published private(set) var selectedSuggestion: NominateUsersDataModel.TypeAheadResult?
    /// Bumped to send the search field back to its placeholder. A value typed but never
    /// picked lives only inside the control, so clearing the model is not enough — this
    /// token is the control's own "start a fresh search" request.
    @Published private(set) var searchResetToken: Int = 0
    @Published private(set) var selectedUsers: [Int: User] = [:]
    @Published private(set) var totalUsersCount: Int = 0
    @Published private(set) var isBatchwiseEnabled: Bool = false

    // Resolved from steps 2–3.
    private var scheduleID: Int?
    private var iltModuleId: Int?
    private var hasLoaded = false

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.NominateUsersNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived UI state
extension NominateUsersViewModel {

    var usersCountText: String { "\(totalUsersCount) users" }
    var nominateButtonTitle: String { "Nominate \(selectedUsers.count)" }
    var isNominateEnabled: Bool { !selectedUsers.isEmpty }
    var isAllSelected: Bool { !items.isEmpty && items.allSatisfy { selectedUsers[$0.id] != nil } }

    func isSelected(_ user: User) -> Bool { selectedUsers[user.id] != nil }
}

// MARK: - Lifecycle / loading
extension NominateUsersViewModel {

    func onAppear() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { [weak self] in await self?.loadEverything() }
    }

    @MainActor
    private func loadEverything() async {
        loadingState = .loading(title: "Loading users", message: "Please wait.")

        // Phase A — independent calls in parallel.
        async let flag: Void = fetchBatchwiseFlag()
        async let cols: Void = fetchColumns()
        async let context: Void = resolveScheduleContext()
        _ = await (flag, cols, context)

        // Phase B — always load the list (best-effort identifiers); count in parallel.
        async let count: Void = fetchUsersCount()
        await loadInitial()
        _ = await count
    }
}

// MARK: - Search (typeahead)
extension NominateUsersViewModel {

    /// A value found under the previous parameter has no meaning under the new one — an
    /// email left in the box while the parameter says "Employee ID" searches for nothing.
    /// So switching parameters empties the search and re-runs the unscoped list.
    func selectColumn(_ column: Column) {
        guard column != selectedColumn else { return }
        selectedColumn = column

        let hadQuery = !searchText.isEmpty || selectedSuggestion != nil
        selectedSuggestion = nil
        searchText = ""
        typeaheadResults = []
        // Nothing was searched, so there is nothing to clear and no list to restore —
        // and no reason to pull focus into an empty box.
        guard hadQuery else { return }
        searchResetToken += 1
        Task { [weak self] in await self?.loadInitial() }
    }

    // Debounce typeahead/list re-queries so they coalesce while typing.
    func onSearchChanged(_ text: String) {
        searchDebouncer.debounce(text) { [weak self] value in
            guard let self else { return }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                self.typeaheadResults = []
                Task { await self.loadInitial() }
            } else {
                Task { await self.fetchTypeahead(trimmed) }
            }
        }
    }

    /// Applying a suggestion re-queries the main list scoped to the selected column.
    func selectSuggestion(_ result: NominateUsersDataModel.TypeAheadResult) {
        selectedSuggestion = result
        if let name = result.name { searchText = name }
        typeaheadResults = []
        Task { [weak self] in await self?.loadInitial() }
    }

    @MainActor
    private func fetchTypeahead(_ text: String) async {
        // Default to the UserName column so search works without forcing a column pick first.
        let columnName = selectedColumn?.configuredColumnName ?? "UserName"
        do {
            let payload = NominateUsersDataModel.TypeAheadPayload(
                searchByColumn: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: columnName),
                searchText: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: text)
            )
            typeaheadResults = try await ApiService.shared.requestPostHeader(
                type: [NominateUsersDataModel.TypeAheadResult].self,
                model: NominateUsersDataModel.GetTypeAheadRequest(),
                payload: payload
            )
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }
}

// MARK: - Selection
extension NominateUsersViewModel {

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

    func clearSelection() {
        selectedUsers.removeAll()
    }

    func loadMoreIfNeeded(currentItem: User) {
        guard shouldLoadMore(currentItem: currentItem) else { return }
        Task { [weak self] in await self?.loadMore() }
    }
}

// MARK: - Actions
extension NominateUsersViewModel {

    func didTapCancel() {
        // Embedded in the Attendance tab there is no screen of our own to pop — dismissing
        // would tear down the host Update Attendance screen — so just drop the selection.
        guard attendanceContext == nil else {
            clearSelection()
            return
        }
        finishFlow()
    }

    func didTapNominate() {
        guard isNominateEnabled else { return }

        // Reached from Update Attendance: a back-dated schedule cannot be nominated for,
        // so the selected users are inserted straight into attendance instead.
        if let context = attendanceContext {
            guard let date = context.date else {
                toast = Toast(style: .warning, message: "Please select the attendance date.")
                return
            }
            guard let statusCode = context.statusCode, !statusCode.isEmpty else {
                toast = Toast(style: .warning, message: "Please select the attendance status.")
                return
            }
            Task { [weak self] in
                await self?.submitAttendance(context: context, date: date, statusCode: statusCode)
            }
            return
        }

        guard let scheduleID, let iltModuleId else {
            toast = Toast(style: .error, message: "Schedule details are still loading. Please try again.")
            return
        }
        Task { [weak self] in await self?.submit(scheduleID: scheduleID, moduleId: iltModuleId) }
    }

    private func finishFlow() {
        router.dismissScreen()
        navModel.onComplete()
    }
}

// MARK: - PaginatableViewModel
extension NominateUsersViewModel {

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [User] {
        let encrypted = try await ApiService.shared.requestPostHeader(
            type: String.self,
            model: NominateUsersDataModel.GetUsersForNominationRequest(),
            payload: usersPayload(page: pageIndex)
        )
        
        guard let data = encrypted.base64DecodedDataPkg,
              let users: [User] =
                data.decryptAndDecodeNew(as: [User].self) else {
            throw APIError.customError(message: encrypted)
        }
        return users
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
extension NominateUsersViewModel {

    private func usersPayload(page: Int) -> NominateUsersDataModel.UsersPayload {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return NominateUsersDataModel.UsersPayload(
            scheduleID: scheduleID ?? 0,
            courseId: courseId,
            moduleId: iltModuleId ?? navModel.moduleID,
            page: page,
            pageSize: itemsPerPage,
            search: selectedColumn?.configuredColumnName,
            searchText: trimmed.isEmpty ? nil : trimmed,
            type: "Nominate"
        )
    }

    @MainActor
    private func fetchBatchwiseFlag() async {
        do {
            let flag = try await ApiService.shared.requestGetHeader(
                type: String.self,
                model: NominateUsersDataModel.IsBatchwiseNominationEnabledRequest()
            )
            isBatchwiseEnabled = flag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "yes"
        } catch {
            // Non-blocking: default to disabled.
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    @MainActor
    private func fetchColumns() async {
        do {
            columns = try await ApiService.shared.requestGetHeader(
                type: [Column].self,
                model: NominateUsersDataModel.GetColumnsRequest()
            )
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    @MainActor
    private func resolveScheduleContext() async {
        guard let scheduleID = navModel.scheduleID else {
            await handleContext()
            return
        }
        self.iltModuleId = navModel.moduleID
        self.scheduleID = scheduleID
    }
    
    private func handleContext() async {
        do {
            let modules = try await ApiService.shared.requestGetHeader(
                type: [ScheduleBasicDetailsDataModel.ModuleItem].self,
                model: ScheduleBasicDetailsDataModel.ModulesByCourseRequest(courseID: "\(courseId)")
            )
            // Prefer the module chosen in the wizard; fall back to the first ILT module.
            let module = modules.first(where: { $0.id == navModel.moduleID }) ?? modules.first
            guard let moduleId = module?.id else { return }
            iltModuleId = moduleId

            do {
                let schedules = try await ApiService.shared.requestGetHeader(
                    type: [NominateUsersDataModel.ModuleSchedule].self,
                    model: NominateUsersDataModel.GetByModuleIdRequest(moduleId: moduleId, courseId: courseId)
                )
                // Fall back to the ILT module id when no schedule row is returned yet.
                scheduleID = schedules.first?.id ?? moduleId
                Logger.shared.log(.info, message: "Nominate: iltModuleId=\(moduleId), scheduleID=\(scheduleID ?? -1)")
            } catch {
                switch error {
                case let apiError as APIError where apiError == .noData:
                    scheduleID =  moduleId
                case let apiError as APIError:
                    handleAPIError(apiError.toUIError(), resetLoadingState: false, showToast: true)
                default:
                    handleAPIError(error, resetLoadingState: false, showToast: true)
                }
            }
            
        } catch {
            switch error {
            case let apiError as APIError:
                handleAPIError(apiError.toUIError(), resetLoadingState: false, showToast: true)
            default:
                handleAPIError(error, resetLoadingState: false, showToast: true)
            }
        }
    }

    @MainActor
    private func fetchUsersCount() async {
        do {
            totalUsersCount = try await ApiService.shared.requestPostHeader(
                type: Int.self,
                model: NominateUsersDataModel.GetUsersCountRequest(),
                payload: usersPayload(page: 1)
            )
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    @MainActor
    private func submit(scheduleID: Int, moduleId: Int) async {
        let body = selectedUsers.values.map { user in
            NominateUsersDataModel.NominateItem(
                userId: user.id,
                userName: user.userName ?? "",
                emailId: user.emailId ?? "",
                mobileNumber: user.mobileNumber ?? ""
            )
        }
        loadingState = .loading(title: "Nominating", message: "Please wait.")
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: NominateUsersDataModel.NominateResponse.self,
                model: NominateUsersDataModel.NominateUserRequest(
                    scheduleID: scheduleID, moduleId: moduleId, courseId: courseId
                ),
                payload: body
            )
            loadingState = .none
            toast = Toast(style: .success, message: response.description ?? "Users nominated successfully.")
            // Let the success toast render before tearing down the sheet + wizard.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            finishFlow()
        } catch let error as APIError {
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }

    /// Insert path used when embedded in Update Attendance. Hits the bare
    /// `ILTTrainingAttendance` endpoint rather than `NominateUser`, and deliberately does
    /// not call `finishFlow()` — dismissing here would pop the host Attendance screen.
    @MainActor
    private func submitAttendance(
        context: NavigationViewModel.NominateAttendanceContext,
        date: Date,
        statusCode: String
    ) async {
        let dateString = date.isoDayStartUTCString
        let body = selectedUsers.values.map { user in
            AttendanceDataModel.InsertItem(
                id: 0,
                isPresent: statusCode == "ATTD",
                userId: user.id,
                moduleId: context.moduleID,
                scheduleId: context.scheduleID,
                courseId: context.courseID,
                isweb: true,
                attendanceStatus: statusCode,
                attendanceDate: dateString,
                withdrewReason: "",
                withdrewRemark: ""
            )
        }
        loadingState = .loading(title: "Nominating", message: "Please wait.")
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: NominateUsersDataModel.NominateResponse.self,
                model: AttendanceDataModel.InsertAttendanceRequest(),
                payload: body
            )
            loadingState = .none
            toast = Toast(style: .success, message: response.description ?? "Attendance added successfully.")
            clearSelection()
            // Let the success toast render before the host reloads its list underneath.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            navModel.onComplete()
        } catch let error as APIError {
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }
}
