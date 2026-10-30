//
//  QuizSettingsViewModel.swift
//  Create_Schedule_Kit
//
//  Create mode posts an empty quiz into the slot and hands its id back. Edit mode only
//  validates and hands the settings back — the editor's Save sends them.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class QuizSettingsViewModel: BaseViewModel {

    typealias DM = QuizSettingsDataModel

    let navModel: NavigationViewModel.QuizSettingsNavModel

    @Published var form: DM.Form
    @Published private(set) var isSubmitting = false

    /// The sheet can be swiped away, so "cancelled" is reported on disappear unless a submit won.
    private var didFinish = false

    init(router: AnyRouter, navModel: NavigationViewModel.QuizSettingsNavModel) {
        self.navModel = navModel
        self.form = navModel.initial
        super.init(router: router)
    }

    var title: String {
        switch navModel.mode {
        case .create: return "Create \(navModel.kind.lowercasedTitle)"
        case .edit:   return "Quiz settings"
        }
    }

    var primaryTitle: String {
        switch navModel.mode {
        case .create: return "Create & add questions"
        case .edit:   return "Apply"
        }
    }

    /// Pass % and duration freeze once a learner has opened the quiz.
    var isScoringLocked: Bool { navModel.isLocked }
}

// MARK: - Actions
extension QuizSettingsViewModel {

    func didTapCancel() {
        router.dismissScreen()
    }

    func onDisappear() {
        guard !didFinish else { return }
        navModel.onCancel()
    }

    func didTapSubmit() {
        guard !isSubmitting else { return }
        if let message = form.validationMessage {
            toast = Toast(style: .warning, message: message)
            return
        }
        guard let settings = form.settings else { return }

        switch navModel.mode {
        case .edit:
            finish(with: .applied(settings))
        case .create(let scheduleID):
            Task { [weak self] in await self?.createQuiz(scheduleID: scheduleID, settings: settings) }
        }
    }

    private func finish(with outcome: DM.Outcome) {
        didFinish = true
        router.dismissScreen()
        navModel.onDone(outcome)
    }
}

// MARK: - API
extension QuizSettingsViewModel {

    @MainActor
    private func createQuiz(scheduleID: Int, settings: QuizDraft.Settings) async {
        isSubmitting = true
        loadingState = .loading(message: "Creating quiz...")
        defer { isSubmitting = false }
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: ScheduleQuizDataModel.IDResponse.self,
                model: ScheduleQuizDataModel.CreateQuizRequest(scheduleID: scheduleID),
                payload: settings.createPayload(kind: navModel.kind)
            )
            loadingState = .none
            finish(with: .created(quizID: response.id))
        } catch {
            handleCreateError(error)
        }
    }

    private func handleCreateError(_ error: Error) {
        guard let apiError = AssessmentAPIError(error) else {
            handleAPIError((error as? APIError)?.toUIError() ?? error, resetLoadingState: true, showToast: true)
            return
        }
        loadingState = .none
        if apiError.statusCode == 409 {
            finish(with: .alreadyExists)
            return
        }
        toast = Toast(
            style: .error,
            message: apiError.statusCode == 404
                ? "This schedule no longer exists."
                : apiError.message(fallback: AssessmentAPIError.genericMessage)
        )
    }
}
