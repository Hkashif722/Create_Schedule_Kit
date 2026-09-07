//
//  ScheduleDetailViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the Schedule Details screen. Schedule info is reused from the tapped list row;
//  the nominees section is a paginated list from ILTTrainingAttendance/GetUsersForAttendance
//  (count fetched in parallel). "+ Add Nominee" reopens the ScheduleNominate sheet.
//

import SwiftUI
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
    @Published private(set) var isDeleteEnabled: Bool = false

    @Published private(set) var details: EditScheduleDataModel.ScheduleDetailsResponse?

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

    /// An external trainer can read the nominee list but not change it, so "+ Add Nominee"
    /// is hidden rather than shown disabled.
    var canNominate: Bool { permissions.canNominate }

    /// Nominee deletion requires both the role permission and the `ATTNOM_DEL` config flag.
    var canDeleteNominees: Bool { canNominate && isDeleteEnabled }

    var deliveryText: String {
        ScheduleListDataModel.Schedule.deliveryText(
            isWebinar: details?.isWebinar ?? schedule.isWebinar,
            webinarType: details?.webinarType ?? schedule.webinarType,
            city: details?.city ?? schedule.city
        )
    }

    var seatCapacityText: String {
        ScheduleListDataModel.Schedule.seatCapacityText(
            seatCapacity: details?.seatCapacity ?? schedule.seatCapacity,
            scheduleCapacity: details?.scheduleCapacity ?? schedule.scheduleCapacity
        )
    }

    var coordinatorText: String {
        ScheduleListDataModel.Schedule.coordinatorText(
            contactPersonName: details?.contactPersonName ?? schedule.contactPersonName
        )
    }
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
        async let detail: Void = fetchDetails()
        async let deleteFlag: Void = fetchDeleteFlag()
        _ = await (list, count, detail, deleteFlag)
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

    /// Both lists are read-only, so they stay open to anyone who can view the schedule —
    /// unlike nominating, which an external trainer cannot do.
    func didTapWaitingList() { openUsers(mode: .waiting) }

    func didTapAvailability() { openUsers(mode: .availability) }

    private func openUsers(mode: ScheduleUsersDataModel.Mode) {
        let navModel = NavigationViewModel.ScheduleUsersNavModel(
            mode: mode,
            scheduleID: schedule.id,
            courseID: schedule.courseID ?? 0,
            moduleID: schedule.moduleId ?? 0
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.scheduleUsers(navModel))
    }

    func didTapAddNominee() {
        guard permissions.canNominate else { return }
        let navModel = NavigationViewModel.NominateUsersNavModel(
            scheduleCode: schedule.scheduleCode ?? "",
            courseID: schedule.courseID ?? 0,
            moduleID: schedule.moduleId ?? 0,
            scheduleID: schedule.id,
            onComplete: { [weak self] in
                Task { await self?.reloadNominees() }
            }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.nominateUsers(navModel))
    }

    func didTapDeleteNominee(_ nominee: Nominee) {
        guard canDeleteNominees else { return }
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
                Task { await self?.deleteNominee(nominee) }
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
extension ScheduleDetailViewModel {

    private func fetchDeleteFlag() async {
        do {
            let response = try await ApiService.shared.requestGetHeader(
                type: ScheduleListDataModel.ConfigValueResponse.self,
                model: ScheduleListDataModel.GetConfigValueRequest(key: "ATTNOM_DEL")
            )
            await MainActor.run { [weak self] in
                self?.isDeleteEnabled = response.isYes
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.handleAPIError(error, resetLoadingState: false, showToast: false)
            }
        }
    }

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

    /// The API wants the AES-encrypted user id, but the list returns only the numeric one
    /// (`userId` there is a plain login name), so it is encrypted in-package.
    private func encryptedUserId(for nominee: Nominee) -> String {
        EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "\(nominee.id)")
    }

    /// Removes a nominee from the schedule. This endpoint answers with an empty body,
    /// so anything that decodes without throwing — including `noData` — counts as success.
    @MainActor
    private func deleteNominee(_ nominee: Nominee) async {
        loadingState = .loading(title: "Deleting", message: "Please wait.")
        let payload = ScheduleDetailDataModel.DeleteNominationPayload(
            scheduleID: schedule.id,
            courseId: schedule.courseID ?? 0,
            moduleId: schedule.moduleId ?? 0,
            userIdEncrypted: encryptedUserId(for: nominee)
        )
        do {
            _ = try await ApiService.shared.requestPostHeader(
                type: EmptyResponse.self,
                model: ScheduleDetailDataModel.DeleteUserNominationRequest(),
                payload: payload
            )
            loadingState = .none
            toast = Toast(style: .success, message: "Record deleted successfully.")
            Logger.shared.log(.info, message: "Schedule Nomitaion deleted for user successfully")
        } catch {
            switch error {
            case let apiError as APIError? where apiError == .noData:
               break
                
            case let apiError as APIError:
                handleAPIError(apiError.toUIError(), showToast: true)
                
            default:
                handleAPIError(error, resetLoadingState: true)
            }
        }
        await reloadNominees()
    }

    @MainActor
    private func fetchDetails() async {
        do {
            details = try await ApiService.shared.requestPostHeader(
                type: EditScheduleDataModel.ScheduleDetailsResponse.self,
                model: EditScheduleDataModel.GetScheduleDetailsByIDRequest(),
                payload: EditScheduleDataModel.GetScheduleDetailsByIDRequest.Payload(scheduleId: schedule.id)
            )
        } catch {
            handleAPIError(error, resetLoadingState: false, showToast: false)
        }
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
