//
//  QuizPreviewViewModel.swift
//  Create_Schedule_Kit
//
//  Read-only Pre/Post quiz: settings, then every question with its options and the right answer.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class QuizPreviewViewModel: BaseViewModel {

    typealias DM = ScheduleQuizDataModel
    typealias PM = QuizPreviewDataModel

    let navModel: NavigationViewModel.QuizPreviewNavModel

    @Published private(set) var detail: DM.QuizDetail?
    @Published private(set) var sections: [PM.Section] = []
    @Published private(set) var loadFailed = false

    init(router: AnyRouter, navModel: NavigationViewModel.QuizPreviewNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived state
extension QuizPreviewViewModel {

    var kind: DM.QuizKind { navModel.kind }

    var headerTitle: String { kind == .pre ? "Pre-Quiz" : "Post-Quiz" }

    var summary: DM.QuizSummary? { detail?.summary }

    var stats: [PM.Stat] { summary.map(PM.stats(from:)) ?? [] }

    var instructions: String? {
        let text = detail?.instructions?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

// MARK: - Load
extension QuizPreviewViewModel {

    func onAppear() {
        guard detail == nil, !loadingState.isLoading else { return }
        Task { [weak self] in await self?.load() }
    }

    func didTapRetry() {
        Task { [weak self] in await self?.load() }
    }

    func didTapBack() {
        router.dismissScreen()
    }

    @MainActor
    private func load() async {
        loadingState = .loading(message: "Loading quiz...")
        do {
            let response = try await ApiService.shared.requestGetHeader(
                type: DM.QuizDetail.self,
                model: DM.GetQuizRequest(quizID: navModel.quizID)
            )
            guard !Task.isCancelled else { return }
            detail = response
            sections = PM.sections(from: response)
            loadFailed = false
            loadingState = .none
        } catch {
            loadFailed = detail == nil
            guard let apiError = AssessmentAPIError(error) else {
                handleAPIError((error as? APIError)?.toUIError() ?? error, resetLoadingState: true, showToast: true)
                return
            }
            loadingState = .none
            toast = Toast(
                style: .error,
                message: apiError.statusCode == 404 ? "This quiz no longer exists." : apiError.message(fallback: "Could not load the quiz.")
            )
        }
    }
}
