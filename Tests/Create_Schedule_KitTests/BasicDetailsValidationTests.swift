//
//  BasicDetailsValidationTests.swift
//  Create_Schedule_KitTests
//
//  Step 1 names the first missing field when Next is tapped on an incomplete form.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct BasicDetailsValidationTests {

    init() {
        SwiftUtilityEnvironment.configure(
            SwiftUtilityConfig(
                encryptionDecryptionKey: "preview-key",
                isBlobEnabled: true,
                orgCode: "preview",
                configurableDate: "dd-MM-yyyy",
                baseURL: "",
                lxpOPath: "",
                lxpBlobPath: "",
                lxpBlobPath1: ""
            )
        )
    }

    private func completeOfflineDraft() -> ScheduleDraft {
        let draft = ScheduleDraft()
        draft.scheduleCode = "SC400"
        draft.course = .init(id: 2810, title: "course 2810", code: "C2810")
        draft.module = .init(id: 662, title: "662_course 2810", type: "classroom",
                             courseFee: 0, currency: "", category: nil, subCategory: nil, subSubCategory: nil)
        draft.deliveryMode = .offline
        let day = Date()
        draft.startDate = day
        draft.endDate = day
        draft.registrationEndDate = day
        draft.startTime = "16:52"
        draft.endTime = "18:52"
        return draft
    }

    @MainActor
    private func viewModel(_ draft: ScheduleDraft, onContinue: @escaping () -> Void = {}) -> ScheduleBasicDetailsViewModel {
        ScheduleBasicDetailsViewModel(
            router: RouterEnvironmentKey.defaultValue,
            draft: draft,
            onBack: {},
            onContinue: onContinue
        )
    }

    @MainActor
    @Test func completeFormHasNothingToReport() {
        let model = viewModel(completeOfflineDraft())

        #expect(model.validationMessage == nil)
        #expect(model.canContinue)
    }

    @MainActor
    @Test func timezoneIsOptional() {
        let draft = completeOfflineDraft()
        draft.timezone = nil

        #expect(viewModel(draft).canContinue)
    }

    @MainActor
    @Test func missingModuleIsNamed() {
        let draft = completeOfflineDraft()
        draft.module = nil

        let model = viewModel(draft)
        #expect(model.canContinue == false)
        #expect(model.validationMessage == "Select a module.")
    }

    @MainActor
    @Test func firstMissingFieldWins() {
        let draft = completeOfflineDraft()
        draft.course = nil
        draft.module = nil
        draft.startTime = nil

        #expect(viewModel(draft).validationMessage == "Select a course.")
    }

    @MainActor
    @Test func missingTimesAreNamed() {
        let noStart = completeOfflineDraft()
        noStart.startTime = nil
        #expect(viewModel(noStart).validationMessage == "Select a start time.")

        let noEnd = completeOfflineDraft()
        noEnd.endTime = nil
        #expect(viewModel(noEnd).validationMessage == "Select an end time.")
    }

    @MainActor
    @Test func endTimeNotAfterStartIsNamed() {
        let draft = completeOfflineDraft()
        draft.endTime = "16:52"

        #expect(viewModel(draft).validationMessage == "End time must be later than start time.")
    }

    @MainActor
    @Test func tappingNextOnAnIncompleteFormToastsTheMissingField() {
        let draft = completeOfflineDraft()
        draft.module = nil
        var didContinue = false

        let model = viewModel(draft, onContinue: { didContinue = true })
        model.didTapContinue()

        #expect(didContinue == false)
        #expect(model.toast?.message == "Select a module.")
        #expect(model.toast?.style == .warning)
    }

    @MainActor
    @Test func tappingNextOnACompleteFormContinues() {
        var didContinue = false

        let model = viewModel(completeOfflineDraft(), onContinue: { didContinue = true })
        model.didTapContinue()

        #expect(didContinue)
        #expect(model.toast == nil)
    }
}
