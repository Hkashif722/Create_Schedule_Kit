//
//  ScheduleListViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the Scheduler landing screen: a paginated schedule list with Upcoming/Completed
//  tabs (filtered client-side by end date — the endpoint has no tab parameter), search, and a
//  "+ New" action that launches the create-schedule wizard. Total count and configurable settings
//  are fetched in parallel with the first page. The rows are refetched when a schedule is created,
//  updated or cancelled, and whenever the screen comes back on top.
//

import Foundation
import Combine
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

enum ScheduleTab: CaseIterable {
    case upcoming
    case completed

    var title: String {
        switch self {
        case .upcoming:  return "Upcoming"
        case .completed: return "Completed"
        }
    }
}

final class ScheduleListViewModel: BaseViewModel, PaginatableViewModel {

    typealias Schedule = ScheduleListDataModel.Schedule

    // MARK: - Dependencies
    private let onFinish: ((CreateScheduleKitEvent) -> Void)?
    /// Long enough that a normal typing cadence produces one request, not one per key.
    private let searchDebouncer = Debouncer<String>(interval: 0.5)

    // MARK: - PaginatableViewModel state
    @Published var items: [Schedule] = []

    // MARK: - Screen state
    @Published var selectedTab: ScheduleTab = .upcoming
    @Published var searchText: String = ""
    /// Column the search text is matched against. Defaults to Module Name, the web client's
    /// default — there is deliberately no "no column" option, which would leave the search box
    /// wired to a request the server ignores.
    @Published private(set) var filterColumn: ScheduleListDataModel.FilterColumn = .moduleName
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var participantCounts: [Int: Int] = [:]
    @Published private(set) var isBatchwiseEnabled: Bool = false
    @Published private(set) var canCancelPastSchedule: Bool = false

    /// A search-driven reload is in flight. Drives a small spinner in the search field and
    /// suppresses the blocking "Fetching records..." overlay — see `setLoadingState`.
    @Published private(set) var isSearching: Bool = false

    private var hasLoaded = false

    /// Column + trimmed query the list currently reflects, so edits that don't change what
    /// would be sent (trailing spaces, retyping the same text) don't refetch.
    private var lastSearchedKey = ""
    private var searchGeneration = 0

    // MARK: - Init
    init(router: AnyRouter, onFinish: ((CreateScheduleKitEvent) -> Void)? = nil) {
        self.onFinish = onFinish
        super.init(router: router)
        subscribeToEvents()
    }
}

// MARK: - Derived UI state
extension ScheduleListViewModel {

    /// Items for the selected tab. The split itself lives on `Schedule.isUpcoming` so the list
    /// tabs and the detail header pill cannot drift apart.
    var displayItems: [Schedule] {
        items.filter { selectedTab == .upcoming ? $0.isUpcoming : !$0.isUpcoming }
    }

    /// True while `fillSelectedTab()` is still walking pages looking for rows for this tab — the
    /// view shows a spinner rather than "no schedules" for that window.
    var isFillingTab: Bool { displayItems.isEmpty && isLoadingMore }

    var searchPlaceholder: String { "Search by \(filterColumn.title)…" }

    /// An external trainer may view a schedule and mark its attendance, nothing more — so
    /// "+ New" and the per-card pencil / cancel actions are hidden outright rather than shown
    /// disabled. Nothing on this screen is left as a dead control.
    var canCreateSchedule: Bool { permissions.canCreateSchedule }
    var canEditSchedule: Bool { permissions.canEditSchedule }
    var canCancelSchedule: Bool { permissions.canCancelSchedule }

    func participantCount(for schedule: Schedule) -> Int {
        participantCounts[schedule.id] ?? schedule.participants
    }
}

// MARK: - Lifecycle / loading
extension ScheduleListViewModel {

    func onAppear() {
        guard !hasLoaded else {
            // Coming back from Attendance / Details / Edit: the rows can be stale, but the org
            // config flags cannot, so only the list and the count are refetched.
            Task { [weak self] in await self?.reloadList() }
            return
        }
        hasLoaded = true
        Task { [weak self] in await self?.loadEverything() }
    }

    @MainActor
    private func loadEverything() async {
        // List, total count, and config settings are all independent → run in parallel.
        async let list: Void = refreshAndFill()
        async let count: Void = fetchCount()
        async let configs: Void = fetchConfigs()
        _ = await (list, count, configs)
    }

    /// Reloads page 1 and then keeps paging until the selected tab has rows to show.
    @MainActor
    private func refreshAndFill() async {
        await refresh()
        await fillSelectedTab()
    }

    /// `GetScheduleData` has no tab parameter, so both tabs are filtered client-side out of one
    /// server-paginated array. A page can be entirely upcoming, which leaves the Completed tab with
    /// no row to fire `loadMoreIfNeeded` — paging would stall and the tab would look permanently
    /// empty. So after every load, keep pulling pages until this tab has something or the server
    /// runs out.
    @MainActor
    private func fillSelectedTab() async {
        while displayItems.isEmpty, hasMore, !isLoadingMore {
            let countBefore = items.count
            await loadMore()
            // A page that added nothing — empty response or a failed request, which leaves
            // `hasMore` untouched — means no progress. Stop rather than spin on it.
            guard items.count > countBefore else { return }
        }
    }

    private func subscribeToEvents() {
        eventPublisher.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .scheduleCreated:
                    Task { await self.refreshAndFill() }
                case .scheduleUpdated:
                    // The wizard is dismissed before this fires, so the list owns
                    // the success feedback.
                    self.toast = Toast(style: .success, message: "Schedule updated successfully.")
                    Task { await self.refreshAndFill() }
                case .cancelled:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Search & tabs
extension ScheduleListViewModel {

    func selectTab(_ tab: ScheduleTab) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        // The new tab may have no rows in what has been fetched so far.
        Task { [weak self] in await self?.fillSelectedTab() }
    }

    /// Typing only ever schedules work: the debouncer coalesces the keystrokes, and the
    /// reload is skipped outright unless what would be sent actually changed.
    func onSearchChanged(_ text: String) {
        searchDebouncer.debounce(text) { [weak self] _ in
            Task { await self?.runSearch() }
        }
    }

    /// Switching column re-runs the current query against it right away — a deliberate tap, so
    /// no debounce. With an empty box there is nothing to re-query.
    func selectFilterColumn(_ column: ScheduleListDataModel.FilterColumn) {
        guard column != filterColumn else { return }
        filterColumn = column
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { [weak self] in await self?.runSearch() }
    }

    @MainActor
    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "\(filterColumn.apiValue)|\(query)"
        guard key != lastSearchedKey else { return }
        lastSearchedKey = key
        // A slower request that is already in flight must not clear the spinner for the
        // request that superseded it.
        searchGeneration += 1
        let generation = searchGeneration
        isSearching = true
        await refreshAndFill()
        if generation == searchGeneration { isSearching = false }
    }

    func loadMoreIfNeeded(currentItem: Schedule) {
        guard currentItem.id == displayItems.last?.id, hasMore, !isLoadingMore else { return }
        Task { [weak self] in await self?.loadMore() }
    }
}

// MARK: - Actions
extension ScheduleListViewModel {

    func didTapNew() {
        guard permissions.canCreateSchedule else { return }
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.createWizard)
    }

    func didTapBack() {
        onFinish?(.cancelled)
        router.dismissScreen()
    }

    func didTapViewDetails(_ schedule: Schedule) {
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.scheduleDetail(.init(schedule: schedule))
        )
    }
    func didTapAttendance(_ schedule: Schedule) {
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.attendance(
                .init(
                    scheduleID: schedule.id,
                    courseID: schedule.courseID ?? 0,
                    moduleID: schedule.moduleId ?? 0,
                    courseName: schedule.courseName ?? "",
                    moduleName: schedule.moduleName ?? "",
                    scheduleCode: schedule.scheduleCode ?? "",
                    dateRangeText: schedule.dateRangeText
                )
            )
        )
    }
    func didTapEdit(_ schedule: Schedule) {
        // The card hides the pencil for a role that cannot edit; this guards a stale tap.
        guard permissions.canEditSchedule else { return }
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.editWizard(scheduleID: schedule.id)
        )
    }

    /// A schedule can only be cancelled up to and including its registration end date. Past that
    /// the action is refused outright — the icon stays on the card either way, so the reason is
    /// explained with a toast rather than by silently hiding it.
    ///
    /// Deliberately NOT softened by the org-level `Enable_PastScheduleCancel` setting: the
    /// registration-end rule is absolute.
    @MainActor
    func didTapCancel(_ schedule: Schedule) {
        guard permissions.canCancelSchedule else { return }

        // The card already hides Cancel for a cancelled schedule; this guards the case where the
        // list is showing a stale row.
        guard !schedule.isCancelled else {
            toast = Toast(style: .info, message: "This schedule is already cancelled.")
            return
        }

        guard schedule.isWithinRegistrationWindow else {
            toast = Toast(
                style: .error,
                message: "Training cannot be canceled, as training already started."
            )
            return
        }

        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.cancelSchedule(
                .init(
                    scheduleID: schedule.id,
                    scheduleCode: schedule.scheduleCode ?? "",
                    moduleName: schedule.title,
                    onCancelled: { [weak self] in
                        guard let self else { return }
                        self.toast = Toast(style: .success, message: "Schedule cancelled successfully.")
                        Task { await self.reloadList() }
                    }
                )
            )
        )
    }
}

// MARK: - PaginatableViewModel
extension ScheduleListViewModel {

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [Schedule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ScheduleListDataModel.ListPayload(
            page: pageIndex,
            pageSize: itemsPerPage,
            // `Search` names the column, `searchText` carries the value. Either both go or
            // neither does — a value with no column is dropped on the floor server-side.
            search: query.isEmpty ? nil : filterColumn.apiValue,
            searchText: query.isEmpty ? nil : query,
            // `"false"` makes the server withhold past schedules, which left the Completed tab
            // with nothing to show. The legacy ILT schedule screen sends `"true"` here too.
            showAllData: "true"
        )
        let schedules = try await ApiService.shared.requestPostHeader(
            type: [Schedule].self,
            model: ScheduleListDataModel.GetScheduleDataRequest(),
            payload: payload
        )
        Task { @MainActor [weak self] in
            await self?.fetchParticipantCounts(for: schedules)
        }
        return schedules
    }

    /// The protocol default puts up a full-screen modal "Fetching records..." overlay for
    /// every page-1 load. That is right for the first load, but while searching the list is
    /// already on screen and the query changes as the user types — the overlay would flash
    /// over the whole screen on each request. A search reload reports itself inline through
    /// `isSearching` instead.
    func setLoadingState(isLoadingMore: Bool) {
        guard !isLoadingMore else { return }
        emptyState = .none
        guard !isSearching else { return }
        loadingState = .loading(title: "Fetching records...", message: "Please wait.")
    }

    func handleFetchError(_ error: Error, isLoadingMore: Bool) {
        if !isLoadingMore {
            loadingState = .none
            emptyState = .error
        }
        handleAPIError(error, resetLoadingState: false, showToast: true)
    }
}

// MARK: - API (count + config)
extension ScheduleListViewModel {

    private func participantCountPayload(
        scheduleID: Int,
        courseID: Int
    ) -> ScheduleListDataModel.NominateUserCountPayload {
        ScheduleListDataModel.NominateUserCountPayload(
            scheduleID: scheduleID,
            courseId: courseID,
            moduleId: 0,
            page: 1,
            pageSize: 10,
            search: "userName",
            searchText: nil,
            search1: nil,
            searchText1: nil,
            type: nil
        )
    }

    @MainActor
    private func fetchParticipantCounts(for schedules: [Schedule]) async {
        let identifiers = schedules.map { (scheduleID: $0.id, courseID: $0.courseID ?? 0) }

        await withTaskGroup(of: (scheduleID: Int, count: Int?).self) { group in
            for identifier in identifiers {
                let payload = participantCountPayload(
                    scheduleID: identifier.scheduleID,
                    courseID: identifier.courseID
                )
                group.addTask {
                    do {
                        let count = try await ApiService.shared.requestPostHeader(
                            type: Int.self,
                            model: ScheduleListDataModel.GetNominateUserCountRequest(),
                            payload: payload
                        )
                        return (identifier.scheduleID, count)
                    } catch {
                        return (identifier.scheduleID, nil)
                    }
                }
            }

            for await result in group {
                if let count = result.count {
                    participantCounts[result.scheduleID] = count
                }
            }
        }
    }

    /// Refetches the rows and the total. Used when the list comes back on screen and after a
    /// cancellation — the cancelled schedule drops out of the list and the total shrinks, so both
    /// need refetching.
    @MainActor
    private func reloadList() async {
        async let list: Void = refreshAndFill()
        async let count: Void = fetchCount()
        _ = await (list, count)
    }

    @MainActor
    private func fetchCount() async {
        do {
            totalCount = try await ApiService.shared.requestGetHeader(
                type: Int.self,
                model: ScheduleListDataModel.ScheduleCountRequest()
            )
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    @MainActor
    private func fetchConfigs() async {
        async let batch: Void = fetchBatchwiseFlag()
        async let cancel: Void = fetchPastCancelFlag()
        _ = await (batch, cancel)
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
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    @MainActor
    private func fetchPastCancelFlag() async {
        let response = try? await ApiService.shared.requestGetHeader(
            type: ScheduleListDataModel.ConfigValueResponse.self,
            model: ScheduleListDataModel.GetConfigValueRequest(key: "Enable_PastScheduleCancel")
        )
        canCancelPastSchedule = response?.isYes ?? false
    }
}
