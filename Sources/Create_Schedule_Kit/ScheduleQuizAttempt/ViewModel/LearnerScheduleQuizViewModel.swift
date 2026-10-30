//
//  LearnerScheduleQuizViewModel.swift
//  Create_Schedule_Kit
//
//  Learner's Live Quiz rows for one schedule. Start and Resume open the full-screen player
//  (which owns the Start call); every way out of the player refetches the rows.
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

    private var hasLoaded = false
    private var loadTask: Task<Void, Never>?

    // MARK: - Init
    init(router: AnyRouter, scheduleID: Int) {
        self.scheduleID = scheduleID
        super.init(router: router)
    }

    deinit { loadTask?.cancel() }
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

    /// No spinner, no toast: the rows sit inside the host's schedule card, and the web just
    /// hides the column when this call fails.
    @MainActor
    private func fetchCards() async {
        do {
            let cards = try await ApiService.shared.requestGetHeader(
                type: DM.ScheduleQuizCards.self,
                model: DM.GetQuizCardsRequest(scheduleID: scheduleID)
            )
            guard !Task.isCancelled else { return }
            slots = cards.slots
        } catch {
            guard !Task.isCancelled else { return }
            // refetch blip keeps the old rows. first load fail = section stays hidden
        }
        hasLoaded = true
    }
}

// MARK: - Actions
extension LearnerScheduleQuizViewModel {

    func didTapSlot(_ slot: LearnerQuizSlot) {
        switch slot.card.status {
        case .ineligible: return
        case .notStarted: confirmStart(slot)
        case .inProgress: openPlayer(slot)
        case .submitted:  openResult(slot)
        }
    }

    /// Start locks the quiz for the manager and, when timed, starts the clock. Worth one tap
    /// of confirmation.
    private func confirmStart(_ slot: LearnerQuizSlot) {
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

    private func openResult(_ slot: LearnerQuizSlot) {
        guard let attemptID = slot.card.attemptId else {
            presentLearnerQuizAlert(
                title: "Result not ready",
                message: "The result isn't available yet. Please try again in a moment.",
                alertType: .info,
                primaryTitle: "OK",
                onPrimary: {}
            )
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

    /// The stale row has no attemptId yet, so wait for the reload `onClose` just kicked off.
    private func openResultAfterReload(kind: ScheduleQuizDataModel.QuizKind) {
        Task { @MainActor [weak self] in
            await self?.loadTask?.value
            // cover still sliding out
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, let fresh = self.slots.first(where: { $0.kind == kind }) else { return }
            self.openResult(fresh)
        }
    }
}
