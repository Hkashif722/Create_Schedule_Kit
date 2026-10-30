//
//  QuizResultViewModel.swift
//  Create_Schedule_Kit
//
//  "View result" from a submitted card. Loads `{attemptId}/Result`; a 409 NotCompleted means
//  the attempt is still open, so the screen offers Resume instead.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class QuizResultViewModel: BaseViewModel {

    typealias DM = ScheduleQuizAttemptDataModel

    enum Phase: Equatable {
        case loading
        case loaded(DM.AttemptResult)
        case notCompleted
        case failed(String)
    }

    // MARK: - Navigation Model
    let navModel: NavigationViewModel.LearnerQuizResultNavModel

    // MARK: - Published State
    @Published private(set) var phase: Phase = .loading

    private var loadTask: Task<Void, Never>?

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.LearnerQuizResultNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }

    deinit { loadTask?.cancel() }

    var canResume: Bool { navModel.onResume != nil }
}

// MARK: - Load
extension QuizResultViewModel {

    func onAppear() {
        guard phase == .loading, loadTask == nil else { return }
        loadTask = Task { [weak self] in await self?.fetchResult() }
    }

    func didTapRetry() {
        phase = .loading
        loadTask?.cancel()
        loadTask = Task { [weak self] in await self?.fetchResult() }
    }

    @MainActor
    private func fetchResult() async {
        do {
            let result = try await ApiService.shared.requestGetHeader(
                type: DM.AttemptResult.self,
                model: DM.GetResultRequest(attemptID: navModel.attemptID)
            )
            guard !Task.isCancelled else { return }
            phase = .loaded(result)
        } catch {
            guard !Task.isCancelled else { return }
            guard let apiError = AssessmentAPIError(error) else {
                reportLearnerQuizError(error)
                phase = .failed("We couldn't load your result. Please try again.")
                return
            }
            switch DM.ResultFailure(apiError) {
            case .notCompleted:
                phase = .notCompleted
            case .notFound:
                phase = .failed("This result is no longer available.")
            case .other:
                phase = .failed(apiError.message(fallback: "We couldn't load your result. Please try again."))
            }
        }
    }
}

// MARK: - Actions
extension QuizResultViewModel {

    func didTapDone() {
        router.dismissScreen()
    }

    func didTapResume() {
        guard let onResume = navModel.onResume else { return }
        router.dismissScreen()
        // the cover has to be gone before the player's cover can come up
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            onResume()
        }
    }
}
