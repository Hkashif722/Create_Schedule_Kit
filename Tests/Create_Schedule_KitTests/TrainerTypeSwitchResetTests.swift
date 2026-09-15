//
//  TrainerTypeSwitchResetTests.swift
//  Create_Schedule_KitTests
//
//  Bug: picking a trainer under one Trainer type and then switching the segment left the
//  trainer's name sitting in the Trainer name field, as if it were the pick for the new
//  type. The field's text lives inside `DropDownMenuListViewPkg`, so the view rebuilds it
//  by keying on `trainerType`; what the view model owns — the results, the keyword and the
//  External source question — is asserted here.
//
//  Already-added chips deliberately survive the switch: the segmented control is how a
//  mixed-type trainer list is built, and each row is saved with the type it was added
//  under (see `CreateSchedulePayloadTests`).
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct TrainerTypeSwitchResetTests {

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

    @MainActor
    private func viewModel(trainerType: TrainerType = .internal) -> ScheduleLogisticsViewModel {
        let draft = ScheduleDraft()
        draft.trainerType = trainerType
        return ScheduleLogisticsViewModel(
            router: RouterEnvironmentKey.defaultValue,
            draft: draft,
            onBack: {},
            onContinue: {}
        )
    }

    private func trainer(
        _ id: String,
        _ name: String,
        userType: String?
    ) -> ScheduleLogisticsDataModel.Trainer {
        .init(
            id: id, name: name, emailId: nil, userId: nil, profilePicture: nil,
            mobileNumber: nil, userType: userType, nameUserId: "\(name) - \(id)"
        )
    }

    // MARK: - The pick resets

    @MainActor
    @Test func switchingTheTypeDropsTheSuggestionsOfThePreviousType() {
        let model = viewModel()
        // Stands in for a finished search; `onTrainerSearch` would hit the network.
        model.trainerResults = [trainer("1", "LMS Admin", userType: nil)]

        model.didSelectTrainerType(.consultant)

        #expect(model.trainerType == .consultant)
        // A stale list belongs to the old type — the field goes back to its placeholder.
        #expect(model.trainerResults.isEmpty)
    }

    /// The External source question is asked per type, so a switch reopens it — and the
    /// menu itself is closed, not left hanging over the new type's field.
    @MainActor
    @Test func switchingTheTypeReopensTheExternalSourceQuestion() {
        let model = viewModel(trainerType: .external)
        model.didSelectTrainerSource(.existingUser)
        #expect(model.showsTrainerSourceMenu == false)

        model.didSelectTrainerType(.internal)

        #expect(model.isTrainerSourceMenuOpen == false)
        // Internal never asks the question at all.
        #expect(model.showsTrainerSourceMenu == false)

        model.didSelectTrainerType(.external)
        #expect(model.showsTrainerSourceMenu)
    }

    // MARK: - What must survive

    /// Chips are how a mixed list is assembled: switching the segment to add a trainer of
    /// another type must not throw away the ones already added.
    @MainActor
    @Test func switchingTheTypeKeepsTheTrainersAlreadyAdded() {
        let model = viewModel()
        model.didSelectTrainer(trainer("1", "LMS Admin", userType: nil))

        model.didSelectTrainerType(.consultant)
        model.didSelectTrainer(trainer("2", "Asha", userType: nil))

        #expect(model.selectedTrainers.count == 2)
        // Each row keeps the type it was added under, which is what the payload sends.
        #expect(model.selectedTrainers.map(\.userType) == ["Internal", "Consultant"])
    }

    /// Re-tapping the selected segment is not a change: it must not wipe the suggestions
    /// or re-ask a source question the organiser has already answered.
    @MainActor
    @Test func reTappingTheSelectedTypeChangesNothing() {
        let model = viewModel(trainerType: .external)
        model.didSelectTrainerSource(.existingUser)
        model.trainerResults = [trainer("1", "Ram", userType: nil)]

        model.didSelectTrainerType(.external)

        #expect(model.trainerResults.count == 1)
        #expect(model.showsTrainerSourceMenu == false)
    }
}
