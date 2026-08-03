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
    private let searchDebouncer = Debouncer<String>(interval: 0.3)

    // MARK: - PaginatableViewModel state
    @Published var items: [User] = []

    // MARK: - Screen state
    @Published var columns: [Column] = []
    @Published var selectedColumn: Column?
    @Published var searchText: String = ""
    @Published var typeaheadResults: [NominateUsersDataModel.TypeAheadResult] = []
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

    func selectColumn(_ column: Column) {
        selectedColumn = column
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

    func loadMoreIfNeeded(currentItem: User) {
        guard shouldLoadMore(currentItem: currentItem) else { return }
        Task { [weak self] in await self?.loadMore() }
    }
}

// MARK: - Actions
extension NominateUsersViewModel {

    func didTapCancel() {
        finishFlow()
    }

    func didTapNominate() {
        guard isNominateEnabled else { return }
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
        do {
            let modules = try await ApiService.shared.requestGetHeader(
                type: [ScheduleBasicDetailsDataModel.ModuleItem].self,
                model: ScheduleBasicDetailsDataModel.ModulesByCourseRequest(courseID: "\(courseId)")
            )
            // Prefer the module chosen in the wizard; fall back to the first ILT module.
            let module = modules.first(where: { $0.id == navModel.moduleID }) ?? modules.first
            guard let moduleId = module?.id else { return }
            iltModuleId = moduleId

            let schedules = try await ApiService.shared.requestGetHeader(
                type: [NominateUsersDataModel.ModuleSchedule].self,
                model: NominateUsersDataModel.GetByModuleIdRequest(moduleId: moduleId, courseId: courseId)
            )
            // Fall back to the ILT module id when no schedule row is returned yet.
            scheduleID = schedules.first?.id ?? moduleId
            Logger.shared.log(.info, message: "Nominate: iltModuleId=\(moduleId), scheduleID=\(scheduleID ?? -1)")
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: true)
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
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }
}
