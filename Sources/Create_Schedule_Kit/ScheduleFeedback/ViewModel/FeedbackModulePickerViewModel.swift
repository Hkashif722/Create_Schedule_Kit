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
    /// Long enough that a normal typing cadence produces one request, not one per key.
    private let searchDebouncer = Debouncer<String>(interval: 0.5)

    // MARK: - PaginatableViewModel state
    @Published var items: [Module] = []

    // MARK: - Picker state
    @Published var selectedID: String?
    @Published var searchText: String = ""
    @Published private(set) var totalRecords: Int = 0

    /// A search-driven reload is in flight — shown inline in the search field instead of
    /// behind the blocking "Fetching records..." overlay. See `setLoadingState`.
    @Published private(set) var isSearching: Bool = false

    /// The trimmed query the list currently reflects, so edits that don't change it don't refetch.
    private var lastSearchedQuery = ""
    private var searchGeneration = 0

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

    /// Typing only ever schedules work: the debouncer coalesces the keystrokes, and the
    /// reload is skipped outright unless the trimmed query actually changed.
    func onSearchChanged(_ text: String) {
        searchDebouncer.debounce(text) { [weak self] value in
            Task { await self?.runSearch(value) }
        }
    }

    @MainActor
    private func runSearch(_ raw: String) async {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != lastSearchedQuery else { return }
        lastSearchedQuery = query
        // A slower request that is already in flight must not clear the spinner for the
        // request that superseded it.
        searchGeneration += 1
        let generation = searchGeneration
        isSearching = true
        await loadInitial()
        if generation == searchGeneration { isSearching = false }
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

    /// Keeps the modal "Fetching records..." overlay for the sheet's first load only — a
    /// search reload reports itself inline through `isSearching` (the list is already up, and
    /// the query changes as the user types).
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
