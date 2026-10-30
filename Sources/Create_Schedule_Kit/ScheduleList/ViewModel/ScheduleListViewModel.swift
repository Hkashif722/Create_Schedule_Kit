//
//  ScheduleListViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the Scheduler landing screen: a paginated schedule list shown in the order the API
//  returns it (no client-side filtering), search, and a
//  "+ New" action that launches the create-schedule wizard. Total count and configurable settings
//  are fetched in parallel with the first page. The rows are refetched when a schedule is created,
//  updated or cancelled, and whenever the screen comes back on top.
//

import Foundation
import Combine
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

/// Where a schedule is in time. Only the detail header pill reads this, the list doesnt filter on it.
enum ScheduleStatus {
    case upcoming
    case ongoing
    case completed

    var title: String {
        switch self {
        case .upcoming:  return "Upcoming"
        case .ongoing:   return "Ongoing"
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
        async let list: Void = refresh()
        async let count: Void = fetchCount()
        async let configs: Void = fetchConfigs()
        _ = await (list, count, configs)
    }

    /// `loadMore()` that drops rows already in the list. If the server ignores `page` and sends
    /// the same rows back, `hasMore` would stay true forever (it only checks the page size) and
    /// every scroll to the bottom would fire another call. A page of nothing but repeats ends
    /// paging. Returns whether any new row came in.
    @MainActor
    @discardableResult
    private func loadNextPage() async -> Bool {
        let idsBefore = items.map(\.id)
        await loadMore()
        // Empty page / failed request, or a refresh swapped the list out mid-flight. Either way
        // there is no appended page here to check.
        guard items.count > idsBefore.count,
              items.prefix(idsBefore.count).map(\.id) == idsBefore else { return false }

        var seen = Set(idsBefore)
        let fresh = items[idsBefore.count...].filter { seen.insert($0.id).inserted }
        if fresh.count < items.count - idsBefore.count {
            items = Array(items.prefix(idsBefore.count)) + fresh
        }
        if fresh.isEmpty { hasMore = false }
        return !fresh.isEmpty
    }

    private func subscribeToEvents() {
        eventPublisher.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .scheduleCreated:
                    Task { await self.refresh() }
                case .scheduleUpdated:
                    // The wizard is dismissed before this fires, so the list owns
                    // the success feedback.
                    self.toast = Toast(style: .success, message: "Schedule updated successfully.")
                    Task { await self.refresh() }
                case .cancelled:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Search
extension ScheduleListViewModel {

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
        await refresh()
        if generation == searchGeneration { isSearching = false }
    }

    func loadMoreIfNeeded(currentItem: Schedule) {
        guard currentItem.id == items.last?.id, hasMore, !isLoadingMore else { return }
        Task { [weak self] in await self?.loadNextPage() }
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

    /// A schedule can normally only be cancelled while it is still Upcoming and inside its
    /// registration window; past either point the action is refused, explained by a toast
    /// (the icon stays on the card either way).
    ///
    /// The org-level `Enable_PastScheduleCancel` setting lifts the two date-based refusals —
    /// see `ScheduleCancelPolicy`, which owns the whole decision so it can be tested with
    /// the flag both ways.
    @MainActor
    func didTapCancel(_ schedule: Schedule) {
        guard permissions.canCancelSchedule else { return }

        // Refusals guard the case where the list is showing a stale row; the card already
        // hides Cancel for a cancelled schedule.
        if let refusal = ScheduleCancelPolicy.refusal(for: schedule, allowsPastCancel: canCancelPastSchedule) {
            toast = Toast(style: refusal.isInformational ? .info : .error, message: refusal.message)
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
        try await requestSchedules(page: pageIndex, pageSize: itemsPerPage)
    }

    private func requestSchedules(page: Int, pageSize: Int) async throws -> [Schedule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ScheduleListDataModel.ListPayload(
            page: page,
            pageSize: pageSize,
            // `Search` names the column, `searchText` carries the value. Either both go or
            // neither does — a value with no column is dropped on the floor server-side.
            search: query.isEmpty ? nil : filterColumn.apiValue,
            searchText: query.isEmpty ? nil : query,
            // `"false"` makes the server withhold past schedules, so finished ones never showed
            // up. The legacy ILT schedule screen sends `"true"` here too.
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

    /// Refetches the rows and the total without disturbing the screen. Used when the list comes
    /// back on top and after a cancellation — the cancelled schedule drops out of the list and
    /// the total shrinks, so both need refetching, but the list is already visible so the rows
    /// are swapped in place rather than reloaded from scratch.
    @MainActor
    private func reloadList() async {
        async let list: Void = silentReload()
        async let count: Void = fetchCount()
        _ = await (list, count)
    }

    /// In-place refresh for a list that is already on screen: refetches the window of rows
    /// currently loaded in one request and swaps them in atomically. `loadingState` is never
    /// touched and `items` is never emptied first, so the ScrollView is not torn down — no
    /// blocking overlay, no flash, and the scroll position survives. A failed refresh keeps the
    /// stale rows rather than disrupt the screen, the same policy as load-more errors.
    @MainActor
    private func silentReload() async {
        // Nothing on screen to preserve — fall back to the regular first-load pipeline.
        guard !items.isEmpty else {
            await refresh()
            return
        }
        do {
            // Page 1 with pageSize = currentPage * itemsPerPage returns the same window as
            // pages 1..currentPage of size itemsPerPage, so loadMore() stays aligned afterwards.
            let window = max(currentPage, 1) * itemsPerPage
            let fresh = try await requestSchedules(page: 1, pageSize: window)
            items = fresh
            hasMore = fresh.count >= window
            emptyState = items.isEmpty ? .noData : .none
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }

    @MainActor
    private func fetchCount() async {
        do {
            totalCount = try await ApiService.shared.requestPostHeader(
                type: Int.self,
                model: ScheduleListDataModel.ScheduleCountRequest(),
                payload: ScheduleListDataModel.CountPayload()
            )
        } catch {
            // count isnt shown anywhere. a failed one used to pop "something went wrong" over a loaded list
            Logger.shared.log(.error, message: "ILTSchedule/count failed: \(error)")
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
            // nothing on the list reads this flag, so fail closed w/o the popup
            isBatchwiseEnabled = false
            Logger.shared.log(.error, message: "IsBatchwiseNominationEnabled failed: \(error)")
        }
    }

    @MainActor
    /// `Enable_PastScheduleCancel` — lets this org cancel schedules whose time has passed.
    /// Fails closed: a config outage leaves the stricter rules in place.
    private func fetchPastCancelFlag() async {
        let response = try? await ApiService.shared.requestGetHeader(
            type: ScheduleListDataModel.ConfigValueResponse.self,
            model: ScheduleListDataModel.GetConfigValueRequest(key: "Enable_PastScheduleCancel")
        )
        canCancelPastSchedule = response?.isYes ?? false
    }
}
