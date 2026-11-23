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
    /// row whose Start tap is waiting on the server re-check. spinner on it, other taps ignored
    @Published private(set) var checkingKind: ScheduleQuizDataModel.QuizKind?

    /// cards are time-gated now ("pre quiz opens at…"), a row loaded once stays locked past its open time
    private var lastLoadedAt: Date?
    private var loadTask: Task<Void, Never>?
    /// rows live in a scrolling list, onAppear fires on every scroll back. dont hammer the api
    private let appearRefreshInterval: TimeInterval = 30

    // MARK: - Init
    init(router: AnyRouter, scheduleID: Int) {
        self.scheduleID = scheduleID
        super.init(router: router)
    }

    deinit { loadTask?.cancel() }
}

// MARK: - Load
extension LearnerScheduleQuizViewModel {

    func onAppear(now: Date = Date()) {
        if let lastLoadedAt, now.timeIntervalSince(lastLoadedAt) < appearRefreshInterval { return }
        reload()
    }

    /// back from background. window may have opened/closed meanwhile, always recheck
    func onBecameActive() {
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
            lastLoadedAt = Date()
        } catch {
            // refetch blip keeps the old rows. first load fail = section stays hidden, next appear retries
        }
    }
}

// MARK: - Actions
extension LearnerScheduleQuizViewModel {

    func didTapSlot(_ slot: LearnerQuizSlot) {
        switch slot.card.status {
        case .ineligible: return
        case .notStarted: recheckThenStart(slot)
        case .inProgress: openPlayer(slot)
        case .submitted:  openResult(slot)
        }
    }

    /// "Start quiz" can be stale (loaded 10:05, window shut 10:15, tapped 10:20). Ask the server
    /// again before the prompt, so a closed quiz never gets as far as the full-screen player.
    private func recheckThenStart(_ slot: LearnerQuizSlot) {
        guard checkingKind == nil else { return }
        checkingKind = slot.kind
        Task { @MainActor [weak self] in
            guard let self else { return }
            let fresh = await self.refetchSlot(kind: slot.kind, fallback: slot)
            self.checkingKind = nil
            switch DM.StartRecheck(fresh: fresh?.card) {
            case .confirm:
                if let fresh { self.confirmStart(fresh) }
            case .closed(let reason):
                self.presentLearnerQuizAlert(
                    title: "\(slot.kind.learnerTitle) isn't open",
                    message: reason,
                    alertType: .info,
                    primaryTitle: "OK",
                    onPrimary: {}
                )
            case .resume:
                if let fresh { self.openPlayer(fresh) }
            case .result:
                if let fresh { self.openResult(fresh) }
            case .gone:
                break
            }
        }
    }

    /// Fresh card for `kind`, rows redrawn on the way. Offline = keep the old card and go on,
    /// Start's own 403 still stops a closed quiz.
    @MainActor
    private func refetchSlot(kind: ScheduleQuizDataModel.QuizKind, fallback: LearnerQuizSlot) async -> LearnerQuizSlot? {
        do {
            let cards = try await ApiService.shared.requestGetHeader(
                type: DM.ScheduleQuizCards.self,
                model: DM.GetQuizCardsRequest(scheduleID: scheduleID)
            )
            slots = cards.slots
            lastLoadedAt = Date()
            return cards.slots.first { $0.kind == kind }
        } catch {
            return fallback
        }
    }

    /// Start locks the quiz for the manager and, when timed, starts the clock. Worth one tap
    /// of confirmation.
    private func confirmStart(_ slot: LearnerQuizSlot) {
        var message = "You get one attempt at this quiz."
        if let minutes = slot.card.durationMinutes {
            // server caps the timer at the window close: a 30-min pre quiz started at 10:12 gets 3 min
            message += slot.card.availableUntil == nil
                ? " The \(minutes)-minute timer starts as soon as you begin."
                : " The timer starts as soon as you begin and runs up to \(minutes) minutes, but stops when the quiz window closes."
        }
        if let instructions = slot.card.instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instructions.isEmpty {
            message += "\n\nInstructions: \(instructions)"
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
            scheduleID: scheduleID,
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
