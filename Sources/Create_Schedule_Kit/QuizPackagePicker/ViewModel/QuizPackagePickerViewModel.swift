//
//  QuizPackagePickerViewModel.swift
//  Create_Schedule_Kit
//
//  Active question packages (`QuestionPackage/GetPackages`, `status: true`), paginated with
//  server-side search. Packages already on the quiz show ticked and disabled. Adding only puts
//  cards on the editor — nothing is saved until the editor's Save.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class QuizPackagePickerViewModel: BaseViewModel, PaginatableViewModel {

    typealias Package = ScheduleQuizDataModel.PackageListItem

    override var itemsPerPage: Int { 20 }

    private let navModel: NavigationViewModel.QuizPackagePickerNavModel
    private let searchDebouncer = Debouncer<String>(interval: 0.5)

    @Published var items: [Package] = []
    @Published var searchText = ""
    /// Picks kept whole, in tap order. A search reload replaces `items`, so resolving ids
    /// against the current page would silently drop anything ticked before the search.
    @Published private(set) var selected: [Package] = []
    @Published private(set) var totalCount = 0
    @Published private(set) var isSearching = false

    private var lastSearchedQuery = ""
    private var searchGeneration = 0

    init(router: AnyRouter, navModel: NavigationViewModel.QuizPackagePickerNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived state
extension QuizPackagePickerViewModel {

    func isAttached(_ package: Package) -> Bool { navModel.attachedIDs.contains(package.id) }

    func isSelected(_ package: Package) -> Bool {
        isAttached(package) || selected.contains { $0.id == package.id }
    }

    /// "1 selected · +5 questions · +10 marks"
    var summaryText: String {
        let questions = selected.reduce(0) { $0 + $1.questionCount - $1.unavailableQuestionCount }
        let marks = selected.reduce(0.0) { $0 + $1.totalMarks }
        return "\(selected.count) selected · +\(questions.questionsLabel) · +\(marks.marksLabel)"
    }

    var addTitle: String {
        selected.count == 1 ? "Add 1 package" : "Add \(selected.count) packages"
    }

    var canAdd: Bool { !selected.isEmpty }

    var countText: String { totalCount == 1 ? "1 package" : "\(totalCount) packages" }
}

// MARK: - Actions
extension QuizPackagePickerViewModel {

    func loadFirstPage() {
        guard items.isEmpty, !loadingState.isLoading else { return }
        Task { [weak self] in await self?.loadInitial() }
    }

    func onSearchChanged(_ text: String) {
        searchDebouncer.debounce(text) { [weak self] value in
            Task { await self?.runSearch(value) }
        }
    }

    func loadMoreIfNeeded(currentItem: Package) {
        guard shouldLoadMore(currentItem: currentItem) else { return }
        Task { [weak self] in await self?.loadMore() }
    }

    func toggle(_ package: Package) {
        guard !isAttached(package) else { return }
        if let index = selected.firstIndex(where: { $0.id == package.id }) {
            selected.remove(at: index)
        } else {
            selected.append(package)
        }
    }

    func didTapClose() {
        router.dismissScreen()
    }

    func didTapAdd() {
        guard !selected.isEmpty else { return }
        let picked = selected
        router.dismissScreen()
        navModel.onAdd(picked)
    }

    @MainActor
    private func runSearch(_ raw: String) async {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != lastSearchedQuery else { return }
        lastSearchedQuery = query
        searchGeneration += 1
        let generation = searchGeneration
        isSearching = true
        await loadInitial()
        if generation == searchGeneration { isSearching = false }
    }
}

// MARK: - PaginatableViewModel
extension QuizPackagePickerViewModel {

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [Package] {
        let generation = searchGeneration
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let page = try await ApiService.shared.requestPostHeader(
            type: ScheduleQuizDataModel.Page<Package>.self,
            model: ScheduleQuizDataModel.GetPackagesRequest(),
            payload: ScheduleQuizDataModel.PackagesPayload(
                page: pageIndex,
                pageSize: itemsPerPage,
                search: query.isEmpty ? nil : query,
                status: true
            )
        )
        // a newer search started while this was in flight. its page must not land
        guard generation == searchGeneration else { throw CancellationError() }
        totalCount = page.totalCount
        return page.data
    }

    func setLoadingState(isLoadingMore: Bool) {
        guard !isLoadingMore else { return }
        emptyState = .none
        guard !isSearching else { return }
        loadingState = .loading(title: "Fetching packages...", message: "Please wait.")
    }

    func handleFetchError(_ error: Error, isLoadingMore: Bool) {
        // stale page from a superseded search, see QuizBankPickerViewModel
        if error is CancellationError {
            if isLoadingMore { currentPage += 1 }
            return
        }
        if !isLoadingMore {
            loadingState = .none
            emptyState = .error
        }
        handleAPIError((error as? APIError)?.toUIError() ?? error, resetLoadingState: false, showToast: true)
    }
}
