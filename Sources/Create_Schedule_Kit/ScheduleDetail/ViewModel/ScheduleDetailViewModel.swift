//
//  ScheduleDetailViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the Schedule Details screen. Schedule info is reused from the tapped list row;
//  the nominees section is a paginated list from ILTTrainingAttendance/GetUsersForAttendance
//  (count fetched in parallel). "+ Add Nominee" reopens the ScheduleNominate sheet.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class ScheduleDetailViewModel: BaseViewModel, PaginatableViewModel {

    typealias Nominee = ScheduleDetailDataModel.Nominee

    // MARK: - Dependencies
    let schedule: ScheduleListDataModel.Schedule

    // MARK: - PaginatableViewModel state (nominees)
    @Published var items: [Nominee] = []

    // MARK: - Screen state
    @Published private(set) var totalNominees: Int = 0

    private var hasLoaded = false

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.ScheduleDetailNavModel) {
        self.schedule = navModel.schedule
        super.init(router: router)
    }
}

// MARK: - Derived UI state
extension ScheduleDetailViewModel {
    var nomineesCountText: String { "\(max(totalNominees, items.count))" }
}

// MARK: - Lifecycle / loading
extension ScheduleDetailViewModel {

    func onAppear() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { [weak self] in await self?.loadEverything() }
    }

    @MainActor
    private func loadEverything() async {
        async let list: Void = loadInitial()
        async let count: Void = fetchNomineesCount()
        _ = await (list, count)
    }

    func loadMoreIfNeeded(currentItem: Nominee) {
        guard shouldLoadMore(currentItem: currentItem) else { return }
        Task { [weak self] in await self?.loadMore() }
    }
}

// MARK: - Actions
extension ScheduleDetailViewModel {

    func didTapBack() {
        router.dismissScreen()
    }

    func didTapAddNominee() {
        let navModel = NavigationViewModel.NominateUsersNavModel(
            scheduleCode: schedule.scheduleCode ?? "",
            courseID: schedule.courseID ?? 0,
            moduleID: schedule.moduleId ?? 0,
            onComplete: { [weak self] in
                Task { await self?.reloadNominees() }
            }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.nominateUsers(navModel))
    }

    func didTapDeleteNominee(_ nominee: Nominee) {
        // TODO: wire the remove-nominee endpoint once provided, then remove locally + refresh count.
        toast = Toast(style: .info, message: "Removing nominees is coming soon.")
    }

    @MainActor
    private func reloadNominees() async {
        async let list: Void = refresh()
        async let count: Void = fetchNomineesCount()
        _ = await (list, count)
    }
}

// MARK: - PaginatableViewModel
extension ScheduleDetailViewModel {

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [Nominee] {
        try await ApiService.shared.requestPostHeader(
            type: [Nominee].self,
            model: ScheduleDetailDataModel.GetUsersForAttendanceRequest(),
            payload: attendancePayload(page: pageIndex)
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
extension ScheduleDetailViewModel {

    private func attendancePayload(page: Int) -> ScheduleDetailDataModel.AttendancePayload {
        ScheduleDetailDataModel.AttendancePayload(
            scheduleID: schedule.id,
            courseId: schedule.courseID ?? 0,
            moduleId: 0,
            page: page,
            pageSize: itemsPerPage,
            searchText: nil,
            search1: nil,
            searchText1: nil,
            type: "Attandance"
        )
    }

    @MainActor
    private func fetchNomineesCount() async {
        do {
            totalNominees = try await ApiService.shared.requestPostHeader(
                type: Int.self,
                model: ScheduleDetailDataModel.GetUsersCountForAttendanceRequest(),
                payload: attendancePayload(page: 1)
            )
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
    }
}
