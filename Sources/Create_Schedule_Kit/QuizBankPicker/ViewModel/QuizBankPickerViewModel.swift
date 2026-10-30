//
//  QuizBankPickerViewModel.swift
//  Create_Schedule_Kit
//
//  "Pick from question bank": `ILTScheduleQuiz/GetBankQuestions`, paginated, with search and
//  difficulty / option-type filters. The server only returns active objective questions and
//  flags `alreadyAdded` against the saved quiz; rows already in the editor (unsaved picks,
//  package questions) are blocked client-side on top of that.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class QuizBankPickerViewModel: BaseViewModel, PaginatableViewModel {

    typealias Question = ScheduleQuizDataModel.BankQuestion
    typealias Difficulty = ScheduleQuizDataModel.Difficulty
    typealias OptionType = ScheduleQuizDataModel.OptionType

    override var itemsPerPage: Int { 20 }

    private let navModel: NavigationViewModel.QuizBankPickerNavModel
    private let searchDebouncer = Debouncer<String>(interval: 0.5)

    @Published var items: [Question] = []
    @Published var searchText = ""
    @Published private(set) var difficulty: Difficulty?
    @Published private(set) var optionType: OptionType?
    @Published private(set) var selected: [Question] = []
    @Published private(set) var totalCount = 0
    @Published private(set) var isSearching = false

    private var lastSearchedQuery = ""
    private var searchGeneration = 0

    init(router: AnyRouter, navModel: NavigationViewModel.QuizBankPickerNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived state
extension QuizBankPickerViewModel {

    func isBlocked(_ question: Question) -> Bool {
        question.alreadyAdded || navModel.blockedIDs.contains(question.id)
    }

    func isSelected(_ question: Question) -> Bool {
        isBlocked(question) || selected.contains { $0.id == question.id }
    }

    var summaryText: String {
        let marks = selected.reduce(0.0) { $0 + $1.marks }
        return "\(selected.count) selected · +\(marks.marksLabel)"
    }

    var addTitle: String {
        selected.count == 1 ? "Add 1 question" : "Add \(selected.count) questions"
    }

    var canAdd: Bool { !selected.isEmpty }

    var countText: String { totalCount == 1 ? "1 question" : "\(totalCount) questions" }

    var difficultyTitle: String { difficulty?.rawValue ?? "All" }
    var optionTypeTitle: String { optionType?.shortTitle ?? "All" }
}

// MARK: - Actions
extension QuizBankPickerViewModel {

    func loadFirstPage() {
        guard items.isEmpty, !loadingState.isLoading else { return }
        Task { [weak self] in await self?.loadInitial() }
    }

    func onSearchChanged(_ text: String) {
        searchDebouncer.debounce(text) { [weak self] value in
            Task { await self?.runSearch(value) }
        }
    }

    func selectDifficulty(_ value: Difficulty?) {
        guard value != difficulty else { return }
        difficulty = value
        reloadForFilter()
    }

    func selectOptionType(_ value: OptionType?) {
        guard value != optionType else { return }
        optionType = value
        reloadForFilter()
    }

    func loadMoreIfNeeded(currentItem: Question) {
        guard shouldLoadMore(currentItem: currentItem) else { return }
        Task { [weak self] in await self?.loadMore() }
    }

    func toggle(_ question: Question) {
        guard !isBlocked(question) else { return }
        if let index = selected.firstIndex(where: { $0.id == question.id }) {
            selected.remove(at: index)
        } else {
            selected.append(question)
        }
    }

    func didTapClose() {
        router.dismissScreen()
    }

    func didTapAdd() {
        guard !selected.isEmpty else { return }
        let picks = selected
        router.dismissScreen()
        navModel.onAdd(picks)
    }

    private func reloadForFilter() {
        Task { [weak self] in await self?.reloadInline() }
    }

    @MainActor
    private func runSearch(_ raw: String) async {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != lastSearchedQuery else { return }
        lastSearchedQuery = query
        await reloadInline()
    }

    /// Filter/search reloads report through the inline spinner, not the blocking overlay.
    @MainActor
    private func reloadInline() async {
        searchGeneration += 1
        let generation = searchGeneration
        isSearching = true
        await loadInitial()
        if generation == searchGeneration { isSearching = false }
    }
}

// MARK: - PaginatableViewModel
extension QuizBankPickerViewModel {

    func fetchItems(pageIndex: Int, isLoadingMore: Bool) async throws -> [Question] {
        let generation = searchGeneration
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let page = try await ApiService.shared.requestPostHeader(
            type: ScheduleQuizDataModel.Page<Question>.self,
            model: ScheduleQuizDataModel.GetBankQuestionsRequest(),
            payload: ScheduleQuizDataModel.BankQuestionsPayload(
                page: pageIndex,
                pageSize: itemsPerPage,
                search: query.isEmpty ? nil : query,
                difficultyLevel: difficulty?.rawValue,
                optionType: optionType?.rawValue,
                quizId: navModel.quizID
            )
        )
        // a newer search/filter started while this was in flight. its page must not land
        guard generation == searchGeneration else { throw CancellationError() }
        totalCount = page.totalCount
        return page.data
    }

    func setLoadingState(isLoadingMore: Bool) {
        guard !isLoadingMore else { return }
        emptyState = .none
        guard !isSearching else { return }
        loadingState = .loading(title: "Fetching questions...", message: "Please wait.")
    }

    func handleFetchError(_ error: Error, isLoadingMore: Bool) {
        // stale page from a superseded query: the newer load owns the state. performFetch
        // already rolled currentPage back for a load-more, which belongs to the new query now
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
