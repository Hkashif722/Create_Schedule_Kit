//
//  QuizInlineQuestionViewModel.swift
//  Create_Schedule_Kit
//
//  Saves the question into the bank (`ILTScheduleQuiz/InlineQuestion`) and hands the editor
//  a direct question with `isCreatedInline`. It only joins the quiz on the editor's Save.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class QuizInlineQuestionViewModel: BaseViewModel {

    typealias DM = QuizInlineQuestionDataModel

    let navModel: NavigationViewModel.QuizInlineQuestionNavModel

    @Published var form = DM.Form()
    @Published private(set) var isSaving = false

    init(router: AnyRouter, navModel: NavigationViewModel.QuizInlineQuestionNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }

    var characterCountText: String { "\(form.questionText.utf16.count)/\(DM.textLimit)" }
}

// MARK: - Actions
extension QuizInlineQuestionViewModel {

    func didTapClose() {
        router.dismissScreen()
    }

    func didSelectOptionType(_ type: ScheduleQuizDataModel.OptionType) {
        form.setOptionType(type)
    }

    func didTapCorrect(_ id: UUID) {
        form.toggleCorrect(id: id)
    }

    func didTapAddOption() {
        form.addOption()
    }

    func didTapRemoveOption(_ id: UUID) {
        form.removeOption(id: id)
    }

    func didTapSave() {
        guard !isSaving else { return }
        if let message = form.validationMessage {
            toast = Toast(style: .warning, message: message)
            return
        }
        guard let payload = form.payload else { return }
        Task { [weak self] in await self?.save(payload) }
    }
}

// MARK: - API
extension QuizInlineQuestionViewModel {

    @MainActor
    private func save(_ payload: ScheduleQuizDataModel.InlineQuestionPayload) async {
        isSaving = true
        loadingState = .loading(message: "Saving question...")
        defer { isSaving = false }
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: ScheduleQuizDataModel.IDResponse.self,
                model: ScheduleQuizDataModel.InlineQuestionRequest(),
                payload: payload
            )
            loadingState = .none
            let question = form.question(id: response.id)
            router.dismissScreen()
            navModel.onSaved(question)
        } catch {
            guard let apiError = AssessmentAPIError(error) else {
                handleAPIError((error as? APIError)?.toUIError() ?? error, resetLoadingState: true, showToast: true)
                return
            }
            loadingState = .none
            let message = apiError.statusCode == 409
                ? "This question already exists in the question bank. Pick it from the bank instead."
                : apiError.message(fallback: AssessmentAPIError.genericMessage)
            toast = Toast(style: .error, message: message)
        }
    }
}
