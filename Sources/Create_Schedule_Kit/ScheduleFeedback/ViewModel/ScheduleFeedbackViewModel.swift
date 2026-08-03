//
//  ScheduleFeedbackViewModel.swift
//  Create_Schedule_Kit
//
//  Step 3 — Feedback. Optional post-session feedback modules attached to the schedule.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities

final class ScheduleFeedbackViewModel: BaseViewModel {

    typealias Module = ScheduleFeedbackDataModel.FeedbackModule

    private let draft: ScheduleDraft
    private let onBack: () -> Void
    private let onContinue: () -> Void
    private let onSkipCreate: () -> Void

    @Published var selectedModule: Module?

    init(router: AnyRouter,
         draft: ScheduleDraft,
         onBack: @escaping () -> Void,
         onContinue: @escaping () -> Void,
         onSkipCreate: @escaping () -> Void) {
        self.draft = draft
        self.onBack = onBack
        self.onContinue = onContinue
        self.onSkipCreate = onSkipCreate
        self.selectedModule = draft.feedbackModule
        super.init(router: router)
    }

    var hasSelection: Bool { selectedModule != nil }

    func openPicker() {
        let navModel = NavigationViewModel.FeedbackPickerNavModel(
            selected: selectedModule,
            onSave: { [weak self] module in
                guard let self else { return }
                self.selectedModule = module
                self.draft.feedbackModule = module
            }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.feedbackPicker(navModel))
    }

    func clearSelection() {
        selectedModule = nil
        draft.feedbackModule = nil
    }

    func didTapBack() {
        draft.feedbackModule = selectedModule
        onBack()
    }

    func didTapContinue() {
        draft.feedbackModule = selectedModule
        onContinue()
    }

    func didTapSkipCreate() {
        draft.feedbackModule = selectedModule
        onSkipCreate()
    }
}
