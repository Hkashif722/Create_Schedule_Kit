//
//  FeedbackModulePickerViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the feedback module picker: server-side search + pagination over `GetModuleData`,
//  filtered to courseType "Feedback". Pagination is handled by SwiftUIUtilities'
//  `PaginatableViewModel` (currentPage / hasMore / isLoadingMore live on the base class).
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class FeedbackModulePickerViewModel: BaseViewModel, PaginatableViewModel {

    typealias Module = ScheduleFeedbackDataModel.FeedbackModule

    // MARK: - Config
    override var itemsPerPage: Int { 20 }

    // MARK: - Dependencies
    private let onSave: (Module) -> Void
    private let searchDebouncer = Debouncer<String>(interval: 0.3)

    // MARK: - PaginatableViewModel state
    @Published var items: [Module] = []

    // MARK: - Picker state
    @Published var selectedID: String?
    @Published var searchText: String = ""
    @Published private(set) var totalRecords: Int = 0

    var chosenModule: Module? { items.first { $0.id == selectedID } }

    init(router: AnyRouter, navModel: NavigationViewModel.FeedbackPickerNavModel) {
        self.onSave = navModel.onSave
        self.selectedID = navModel.selected?.id
        super.init(router: router)
    }

    // MARK: - Loading

    func loadFirstPage() {
        guard items.isEmpty, !loadingState.isLoading else { return }
        Task { [weak self] in await self?.loadInitial() }
    }

    func onSearchChanged(_ text: String) {
        searchDebouncer.debounce(text) { [weak self] _ in
            guard let self else { return }
            Task { await self.loadInitial() }
        }
    }

    func loadMoreIfNeeded(currentItem: Module) {
        guard shouldLoadMore(currentItem: currentItem) else { return }
        Task { [weak self] in await self?.loadMore() }
    }

    // MARK: - Selection

    /// Single-select (radio): selecting a row replaces any prior choice; tapping the chosen row clears it.
    func select(_ module: Module) {
        selectedID = (selectedID == module.id) ? nil : module.id
    }

    func save() {
        guard let chosenModule else { return }
        onSave(chosenModule)
        router.dismissScreen()
    }

    // MARK: - PaginatableViewModel

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [Module] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ScheduleFeedbackDataModel.GetModuleDataRequest.Payload(
            page: pageIndex,
            pageSize: itemsPerPage,
            search: "Feedback",
            searchString: trimmed.isEmpty ? nil : trimmed,
            columnName: "coursetype",
            showAllData: true
        )

        let response = try await ApiService.shared.requestPostHeader(
            type: ScheduleFeedbackDataModel.GetModuleDataResponse.self,
            model: ScheduleFeedbackDataModel.GetModuleDataRequest(),
            payload: payload
        )
        totalRecords = response.totalRecords
        return response.data.map { Module(dto: $0) }
    }

    func handleFetchError(_ error: Error, isLoadingMore: Bool) {
        if !isLoadingMore {
            loadingState = .none
            emptyState = .error
        }
        handleAPIError(error, resetLoadingState: false, showToast: true)
    }
}
