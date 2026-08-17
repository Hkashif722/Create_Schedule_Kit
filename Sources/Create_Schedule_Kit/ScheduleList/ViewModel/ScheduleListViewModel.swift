//
//  ScheduleListViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the Scheduler landing screen: a paginated schedule list with Upcoming/Completed
//  tabs (filtered client-side by date), search, and a "+ New" action that launches the
//  create-schedule wizard. Total count and configurable settings are fetched in parallel
//  with the first page. The list refreshes when a schedule is created.
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
    private let searchDebouncer = Debouncer<String>(interval: 0.3)

    // MARK: - PaginatableViewModel state
    @Published var items: [Schedule] = []

    // MARK: - Screen state
    @Published var selectedTab: ScheduleTab = .upcoming
    @Published var searchText: String = ""
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var isBatchwiseEnabled: Bool = false
    @Published private(set) var canCancelPastSchedule: Bool = false

    private var hasLoaded = false

    // MARK: - Init
    init(router: AnyRouter, onFinish: ((CreateScheduleKitEvent) -> Void)? = nil) {
        self.onFinish = onFinish
        super.init(router: router)
        subscribeToEvents()
    }
}

// MARK: - Derived UI state
extension ScheduleListViewModel {

    /// Items for the selected tab, split by end date vs. the start of today.
    var displayItems: [Schedule] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return items.filter { schedule in
            guard let end = schedule.endDateValue else {
                return selectedTab == .upcoming   // undated → treat as upcoming
            }
            switch selectedTab {
            case .upcoming:  return end >= startOfToday
            case .completed: return end < startOfToday
            }
        }
    }
}

// MARK: - Lifecycle / loading
extension ScheduleListViewModel {

    func onAppear() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { [weak self] in await self?.loadEverything() }
    }

    @MainActor
    private func loadEverything() async {
        // List, total count, and config settings are all independent → run in parallel.
        async let list: Void = loadInitial()
        async let count: Void = fetchCount()
        async let configs: Void = fetchConfigs()
        _ = await (list, count, configs)
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

// MARK: - Search & tabs
extension ScheduleListViewModel {

    func selectTab(_ tab: ScheduleTab) {
        selectedTab = tab
    }

    func onSearchChanged(_ text: String) {
        searchDebouncer.debounce(text) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func loadMoreIfNeeded(currentItem: Schedule) {
        guard currentItem.id == displayItems.last?.id, hasMore, !isLoadingMore else { return }
        Task { [weak self] in await self?.loadMore() }
    }
}

// MARK: - Actions
extension ScheduleListViewModel {

    func didTapNew() {
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
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.editWizard(scheduleID: schedule.id)
        )
    }
}

// MARK: - PaginatableViewModel
extension ScheduleListViewModel {

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [Schedule] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ScheduleListDataModel.ListPayload(
            page: pageIndex,
            pageSize: itemsPerPage,
            search: nil,
            searchText: trimmed.isEmpty ? nil : trimmed,
            showAllData: "false"
        )
        return try await ApiService.shared.requestPostHeader(
            type: [Schedule].self,
            model: ScheduleListDataModel.GetScheduleDataRequest(),
            payload: payload
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

// MARK: - API (count + config)
extension ScheduleListViewModel {

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
        do {
            let response = try await ApiService.shared.requestGetHeader(
                type: ScheduleListDataModel.ConfigValueResponse.self,
                model: ScheduleListDataModel.GetConfigValueRequest(key: "Enable_PastScheduleCancel")
            )
            canCancelPastSchedule = (response.value ?? "").lowercased() == "yes"
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }
}
