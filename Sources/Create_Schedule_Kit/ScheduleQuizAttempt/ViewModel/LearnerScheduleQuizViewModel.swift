//
//  LearnerScheduleQuizViewModel.swift
//  Create_Schedule_Kit
//
//  Learner's Pre/Post quiz cards for one schedule. Start and Resume open the full-screen
//  player (which owns the Start call); every way out of the player refetches the cards.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class LearnerScheduleQuizViewModel: BaseViewModel {

    typealias DM = ScheduleQuizAttemptDataModel

    // MARK: - State
    let scheduleID: Int
    @Published private(set) var slots: [LearnerQuizSlot] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var loadFailed = false

    private var loadTask: Task<Void, Never>?

    // MARK: - Init
    init(router: AnyRouter, scheduleID: Int) {
        self.scheduleID = scheduleID
        super.init(router: router)
    }

    deinit { loadTask?.cancel() }
}

// MARK: - Derived UI state
extension LearnerScheduleQuizViewModel {

    var showsEmptyState: Bool { hasLoaded && !loadFailed && slots.isEmpty }
    var showsInitialSpinner: Bool { !hasLoaded && slots.isEmpty }
}

// MARK: - Load
extension LearnerScheduleQuizViewModel {

    func onAppear() {
        guard !hasLoaded, loadTask == nil else { return }
        reload()
    }

    func reload() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in await self?.fetchCards() }
    }

    @MainActor
    private func fetchCards() async {
        // first load has its own inline spinner
        if hasLoaded { loadingState = .loading(message: "Loading quizzes...") }
        do {
            let cards = try await ApiService.shared.requestGetHeader(
                type: DM.ScheduleQuizCards.self,
                model: DM.GetQuizCardsRequest(scheduleID: scheduleID)
            )
            guard !Task.isCancelled else { return }
            slots = cards.slots
            loadFailed = false
            hasLoaded = true
            loadingState = .none
        } catch {
            guard !Task.isCancelled else { return }
            hasLoaded = true
            loadFailed = slots.isEmpty
            reportLearnerQuizError(error)
        }
    }
}

// MARK: - Actions
extension LearnerScheduleQuizViewModel {

    func didTapBack() {
        router.dismissScreen()
    }

    /// Start locks the quiz for the manager and, when timed, starts the clock. Worth one tap
    /// of confirmation.
    func didTapStart(_ slot: LearnerQuizSlot) {
        var message = "You get one attempt at this quiz."
        if let minutes = slot.card.durationMinutes {
            message += " The \(minutes)-minute timer starts as soon as you begin."
        }
        presentLearnerQuizAlert(
            title: "Start \(slot.kind.lowercasedTitle)?",
            message: message,
            alertType: .info,
            primaryTitle: "Start",
            secondaryTitle: "Cancel",
            onPrimary: { [weak self] in
                // let the popup finish leaving before the cover slides in
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    self?.openPlayer(slot)
                }
            }
        )
    }

    func didTapResume(_ slot: LearnerQuizSlot) {
        openPlayer(slot)
    }

    func didTapViewResult(_ slot: LearnerQuizSlot) {
        guard let attemptID = slot.card.attemptId else {
            toast = Toast(style: .warning, message: "The result isn't available yet.")
            return
        }
        let navModel = NavigationViewModel.LearnerQuizResultNavModel(
            attemptID: attemptID,
            kind: slot.kind,
            title: slot.card.title,
            onResume: { [weak self] in self?.openPlayer(slot) }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.learnerQuizResult(navModel))
    }

    private func openPlayer(_ slot: LearnerQuizSlot) {
        let navModel = NavigationViewModel.LearnerQuizPlayerNavModel(
            quizID: slot.card.quizId,
            kind: slot.kind,
            title: slot.card.title,
            onClose: { [weak self] in self?.reload() },
            onViewResult: { [weak self] in self?.openResultAfterReload(kind: slot.kind) }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.learnerQuizPlayer(navModel))
    }

    /// The stale card has no attemptId yet, so wait for the reload `onClose` just kicked off.
    private func openResultAfterReload(kind: ScheduleQuizDataModel.QuizKind) {
        Task { @MainActor [weak self] in
            await self?.loadTask?.value
            // cover still sliding out
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, let fresh = self.slots.first(where: { $0.kind == kind }) else { return }
            self.didTapViewResult(fresh)
        }
    }
}
