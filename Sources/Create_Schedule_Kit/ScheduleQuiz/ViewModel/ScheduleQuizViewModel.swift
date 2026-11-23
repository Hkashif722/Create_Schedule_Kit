//
//  ScheduleQuizViewModel.swift
//  Create_Schedule_Kit
//
//  The Pre and Post slots of one schedule. An empty slot offers "Create pre quiz", a filled one
//  Edit / Delete. Delete is refused once a learner started the quiz. Same as web, no on/off switch.
//  The quiz itself is built in `QuizEditorView`.
//
//  Used twice: pushed on its own from a schedule card / Schedule Details, and embedded as the
//  wizard's last step once the schedule exists (the quiz API needs its id).
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class ScheduleQuizViewModel: BaseViewModel {

    typealias DM = ScheduleQuizDataModel

    enum Presentation {
        case standalone
        case wizardStep(onFinish: () -> Void)

        var isWizardStep: Bool {
            if case .wizardStep = self { return true }
            return false
        }
    }

    let navModel: NavigationViewModel.ScheduleQuizNavModel
    let presentation: Presentation

    @Published private(set) var quizzes: DM.ScheduleQuizzes?
    @Published private(set) var loadFailed = false
    /// Create sheet is up for this slot. Blocks a 2nd sheet / double editor push.
    @Published private(set) var pendingCreate: DM.QuizKind?
    /// Delete confirm is up for this slot.
    @Published private(set) var pendingDelete: DM.QuizKind?

    /// Sheet → push hand-offs need the sheet fully gone first, same as the wizard's nominate step.
    private let presentationDelay: UInt64 = 350_000_000

    init(router: AnyRouter, navModel: NavigationViewModel.ScheduleQuizNavModel, presentation: Presentation) {
        self.navModel = navModel
        self.presentation = presentation
        super.init(router: router)
    }
}

// MARK: - Derived state
extension ScheduleQuizViewModel {

    var hasLoaded: Bool { quizzes != nil }

    func quiz(_ kind: DM.QuizKind) -> DM.QuizSummary? { quizzes?.quiz(kind) }

    var isSlotActionEnabled: Bool {
        hasLoaded && pendingCreate == nil && pendingDelete == nil && !loadingState.isLoading
    }

    func emptySlotText(_ kind: DM.QuizKind) -> String {
        kind == .pre
            ? "Learners take it before the session starts."
            : "Learners take it after the session. Create it now and add questions in the editor."
    }
}

// MARK: - Load
extension ScheduleQuizViewModel {

    func onAppear() {
        guard !hasLoaded, !loadingState.isLoading else { return }
        Task { [weak self] in await self?.load(showsLoader: true) }
    }

    func didTapRetry() {
        Task { [weak self] in await self?.load(showsLoader: true) }
    }

    @MainActor
    private func load(showsLoader: Bool) async {
        if showsLoader { loadingState = .loading(message: "Loading quizzes...") }
        do {
            quizzes = try await ApiService.shared.requestGetHeader(
                type: DM.ScheduleQuizzes.self,
                model: DM.GetScheduleQuizzesRequest(scheduleID: navModel.scheduleID)
            )
            loadFailed = false
            loadingState = .none
        } catch {
            loadFailed = quizzes == nil
            handleAPIError((error as? APIError)?.toUIError() ?? error, resetLoadingState: true, showToast: true)
        }
    }

    private func reload() {
        Task { [weak self] in await self?.load(showsLoader: false) }
    }
}

// MARK: - Actions
extension ScheduleQuizViewModel {

    func didTapCreate(_ kind: DM.QuizKind) {
        guard isSlotActionEnabled else { return }
        openCreate(kind)
    }

    func didTapEdit(_ kind: DM.QuizKind) {
        guard let quiz = quiz(kind) else { return }
        openEditor(quizID: quiz.id, kind: kind)
    }

    func didTapDelete(_ kind: DM.QuizKind) {
        guard isSlotActionEnabled, let quiz = quiz(kind) else { return }
        // already started, server says no anyway. skip the call
        if quiz.isDeleteBlocked {
            showDeleteBlocked(quiz)
            return
        }
        confirmDelete(kind)
    }

    func didTapBack() {
        router.dismissScreen()
    }

    func didTapFinish() {
        guard case .wizardStep(let onFinish) = presentation else { return }
        onFinish()
    }

    private func openCreate(_ kind: DM.QuizKind) {
        guard quiz(kind) == nil else { return }
        pendingCreate = kind
        let navModel = NavigationViewModel.QuizSettingsNavModel(
            kind: kind,
            mode: .create(scheduleID: self.navModel.scheduleID),
            initial: .defaults(kind: kind, displayName: self.navModel.displayName),
            isLocked: false,
            onDone: { [weak self] outcome in
                switch outcome {
                case .created(let quizID): self?.didCreate(quizID: quizID, kind: kind)
                case .alreadyExists:       self?.didFindExisting(kind)
                case .applied:             break
                }
            },
            // a failed create may mean the slot moved under us. cheap to just refetch
            onCancel: { [weak self] in
                self?.pendingCreate = nil
                self?.reload()
            }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.quizSettings(navModel))
    }

    /// `pendingCreate` stays set until the editor is pushed, so a second tap in the delay
    /// can't open another sheet or push the editor twice.
    private func didCreate(quizID: Int, kind: DM.QuizKind) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.load(showsLoader: false)
            try? await Task.sleep(nanoseconds: self.presentationDelay)
            self.openEditor(quizID: quizID, kind: kind)
            self.pendingCreate = nil
        }
    }

    private func didFindExisting(_ kind: DM.QuizKind) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.load(showsLoader: false)
            guard let quiz = self.quiz(kind) else {
                self.pendingCreate = nil
                self.toast = Toast(style: .error, message: "This schedule already has a \(kind.lowercasedTitle).")
                return
            }
            self.toast = Toast(style: .info, message: "This schedule already has a \(kind.lowercasedTitle). Opening it.")
            try? await Task.sleep(nanoseconds: self.presentationDelay)
            self.openEditor(quizID: quiz.id, kind: kind)
            self.pendingCreate = nil
        }
    }

    private func openEditor(quizID: Int, kind: DM.QuizKind) {
        let navModel = NavigationViewModel.QuizEditorNavModel(
            quizID: quizID,
            kind: kind,
            onChanged: { [weak self] in self?.reload() },
            isOtherSlotEmpty: { [weak self] in self?.quiz(kind.other) == nil },
            onAddOtherQuiz: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: self.presentationDelay)
                    self.openCreate(kind.other)
                }
            },
            onFinish: presentation.isWizardStep ? { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: self.presentationDelay)
                    self.didTapFinish()
                }
            } : nil
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.quizEditor(navModel))
    }
}

// MARK: - Delete
extension ScheduleQuizViewModel {

    private func confirmDelete(_ kind: DM.QuizKind) {
        guard let quiz = quiz(kind) else { return }
        pendingDelete = kind
        let model = CustomAlertPopupModel(
            title: AttributedString("Delete \(quiz.title)?"),
            alertType: .warning,
            content: {
                Text("This frees the slot so a new \(kind.lowercasedTitle) can be created.")
                    .multilineTextAlignment(.center)
                    .padding()
            },
            primaryButtonTitle: "Delete",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
                Task { [weak self] in await self?.delete(quiz: quiz, kind: kind) }
            },
            secondaryButtonTitle: "Cancel",
            secondaryAction: { [weak self] in
                self?.pendingDelete = nil
                self?.router.dismissModal()
            }
        )
        showPopup(model)
    }

    /// Learner already started it. Just say so, no way around it (web has none either).
    private func showDeleteBlocked(_ quiz: DM.QuizSummary) {
        let model = CustomAlertPopupModel(
            title: "Can't delete this quiz",
            alertType: .warning,
            content: {
                Text(quiz.deleteBlockedMessage)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
            },
            primaryButtonTitle: "OK",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
            }
        )
        showPopup(model)
    }

    @MainActor
    private func delete(quiz: DM.QuizSummary, kind: DM.QuizKind) async {
        loadingState = .loading(message: "Deleting quiz...")
        do {
            _ = try await ApiService.shared.requestDeleteHeader(
                type: DM.APIMessage.self,
                model: DM.DeleteQuizRequest(quizID: quiz.id)
            )
            await load(showsLoader: false)
            pendingDelete = nil
            toast = Toast(style: .success, message: "\(kind.shortTitle) deleted.")
        } catch {
            let apiError = AssessmentAPIError(error)
            // card was stale, a learner got in after we loaded. refetch so it shows Locked
            if apiError?.statusCode == 409 {
                loadingState = .none
                await load(showsLoader: false)
                pendingDelete = nil
                try? await Task.sleep(nanoseconds: presentationDelay)
                showDeleteBlocked(self.quiz(kind) ?? quiz)
                return
            }
            pendingDelete = nil
            if apiError?.statusCode == 404 {
                loadingState = .none
                await load(showsLoader: false)
                return
            }
            if let apiError {
                loadingState = .none
                toast = Toast(style: .error, message: apiError.message(fallback: "Could not delete the quiz."))
            } else {
                handleAPIError((error as? APIError)?.toUIError() ?? error, resetLoadingState: true, showToast: true)
            }
        }
    }

    private func showPopup(_ model: CustomAlertPopupModel) {
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.customAlertPopupView(model))
        )
    }
}
