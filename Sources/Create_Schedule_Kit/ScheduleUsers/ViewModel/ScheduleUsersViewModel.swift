//
//  ScheduleUsersViewModel.swift
//  Create_Schedule_Kit
//
//  Drives both user lists reachable from Schedule Details. `mode` decides the route, the
//  response shape and the copy; everything else — paging, search, empty handling — is
//  shared.
//

import Foundation
import NetworkService
import SwiftfulRouting
import SwiftUIUtilities

final class ScheduleUsersViewModel: BaseViewModel, PaginatableViewModel {

    typealias User = ScheduleUsersDataModel.ScheduleUser

    /// The column the search box filters on. The server pairs it with `searchText`.
    private static let searchColumn = "userName"

    // MARK: - Dependencies
    let navModel: NavigationViewModel.ScheduleUsersNavModel

    // MARK: - PaginatableViewModel state
    @Published var items: [User] = []

    // MARK: - Screen state
    @Published var searchText: String = ""
    @Published private(set) var totalRecords: Int = 0
    /// A search-driven reload is in flight. Drives the spinner inside the field and keeps
    /// the blocking overlay away — see `setLoadingState`.
    @Published private(set) var isSearching: Bool = false

    private let searchDebouncer = Debouncer<String>(interval: 0.5)
    private var hasLoaded = false
    /// The query the list currently reflects, so edits that would send the same thing
    /// (trailing spaces, retyping) don't refetch.
    private var lastSearchedQuery = ""
    private var searchGeneration = 0

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.ScheduleUsersNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived UI State
extension ScheduleUsersViewModel {

    var mode: ScheduleUsersDataModel.Mode { navModel.mode }

    var title: String { mode.title }

    /// "USERS (4)" once a total is known, otherwise the bare caption.
    var sectionTitle: String {
        totalRecords > 0 ? "\(mode.sectionTitle) (\(totalRecords))" : mode.sectionTitle
    }

    var searchPlaceholder: String { "Search users…" }
}

// MARK: - Actions
extension ScheduleUsersViewModel {

    func onAppear() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { [weak self] in await self?.loadEverything() }
    }

    /// Typing only ever schedules work: the debouncer coalesces keystrokes, and the reload
    /// is skipped outright unless the trimmed query actually changed.
    func onSearchChanged(_ text: String) {
        searchDebouncer.debounce(text) { [weak self] value in
            Task { await self?.runSearch(value) }
        }
    }

    func loadMoreIfNeeded(currentItem: User) {
        guard shouldLoadMore(currentItem: currentItem) else { return }
        Task { [weak self] in await self?.loadMore() }
    }

    func didTapBack() {
        Task { @MainActor [weak self] in self?.router.dismissScreen() }
    }
}

// MARK: - API
extension ScheduleUsersViewModel {

    @MainActor
    private func loadEverything() async {
        // The waiting envelope reports its own total, so only availability needs the
        // second call — and it is independent of the list, so it runs alongside it.
        if mode.needsSeparateCountCall {
            async let count: Void = fetchUsersCount()
            await loadInitial()
            _ = await count
        } else {
            await loadInitial()
        }
    }

    @MainActor
    private func runSearch(_ raw: String) async {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != lastSearchedQuery else { return }
        lastSearchedQuery = query

        // A slower request already in flight must not clear the spinner for the request
        // that superseded it.
        searchGeneration += 1
        let generation = searchGeneration
        isSearching = true
        if mode.needsSeparateCountCall { await fetchUsersCount() }
        await loadInitial()
        if generation == searchGeneration { isSearching = false }
    }

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [User] {
        switch mode {
        case .waiting:
            let response = try await ApiService.shared.requestPostHeader(
                type: ScheduleUsersDataModel.WaitingResponse.self,
                model: ScheduleUsersDataModel.GetUsersForWaitingRequest(),
                payload: payload(page: pageIndex)
            )
            totalRecords = response.totalRecords ?? response.users.count
            return response.users

        case .availability:
            return try await ApiService.shared.requestPostHeader(
                type: [User].self,
                model: ScheduleUsersDataModel.GetUsersForAttendanceRequest(),
                payload: payload(page: pageIndex)
            )
        }
    }

    @MainActor
    private func fetchUsersCount() async {
        do {
            totalRecords = try await ApiService.shared.requestPostHeader(
                type: Int.self,
                model: ScheduleUsersDataModel.GetUsersCountForAttendanceRequest(),
                payload: payload(page: 1)
            )
        } catch {
            if let apiError = error as? APIError, case .noData = apiError {
                totalRecords = 0
            } else {
                // Silent: the list itself reports any real failure, and a count that did
                // not arrive is not worth a second toast over the same request.
                handleAPIError(error, resetLoadingState: false, showToast: false)
            }
        }
    }

    func payload(page: Int) -> ScheduleUsersDataModel.UsersPayload {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return ScheduleUsersDataModel.UsersPayload(
            scheduleID: navModel.scheduleID,
            courseId: navModel.courseID,
            // The sibling attendance payloads send 0 here rather than the real module id.
            moduleId: 0,
            page: page,
            pageSize: itemsPerPage,
            // `search` names the column and `searchText` carries the value — either both
            // go or neither does, since a value with no column is dropped server-side.
            search: query.isEmpty ? nil : Self.searchColumn,
            searchText: query.isEmpty ? nil : query,
            search1: nil,
            searchText1: nil,
            type: mode.apiType
        )
    }

    /// An empty list is a fact, not a failure — the waiting list is empty most of the time.
    func handleFetchError(_ error: Error, isLoadingMore: Bool) {
        if let apiError = error as? APIError, case .noData = apiError {
            hasMore = false
            if !isLoadingMore {
                items = []
                totalRecords = 0
                loadingState = .loaded
                emptyState = .noData
            }
            return
        }

        if !isLoadingMore {
            loadingState = .none
            emptyState = .error
        }
        handleAPIError(error, resetLoadingState: false, showToast: true)
    }

    /// The protocol default throws up a blocking "Fetching records..." overlay for every
    /// page-1 load. Right on first open, wrong while searching — the list is already on
    /// screen and the query changes as the user types, so that reload reports itself
    /// inline through `isSearching` instead.
    func setLoadingState(isLoadingMore: Bool) {
        guard !isLoadingMore else { return }
        emptyState = .none
        guard !isSearching else { return }
        loadingState = .loading(title: "Fetching records...", message: "Please wait.")
    }
}
