//
//  ScheduleDetailTrainerListTests.swift
//  Create_Schedule_KitTests
//
//  Pins the TRAINERS section on Schedule Details: the screen lists every trainer from
//  `GetScheduleDetailsByID.trainerList` (a schedule can have several), and falls back to
//  the single trainer carried by the tapped list row until that call lands.
//

import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct ScheduleDetailTrainerListTests {

    private typealias TrainerDisplay = ScheduleDetailDataModel.TrainerDisplay

    private func item(
        id: Int? = 1,
        name: String? = "Chetan Wade",
        type: String? = "internal",
        nameUserId: String? = nil
    ) -> EditScheduleDataModel.TrainerItem {
        EditScheduleDataModel.TrainerItem(
            academyTrainerID: id,
            academyTrainerName: name,
            trainerType: type,
            emailID: nil,
            trainerEmail: nil,
            nameUserId: nameUserId
        )
    }

    @Test("Every trainer on the schedule is listed")
    func listsAllTrainers() {
        let rows = TrainerDisplay.list(
            from: [item(id: 1, name: "Chetan Wade"), item(id: 2, name: "Kashif User", type: "External")],
            scheduleTrainerType: "Internal",
            fallbackName: "Chetan Wade",
            fallbackType: "Internal"
        )
        #expect(rows.map(\.name) == ["Chetan Wade", "Kashif User"])
        #expect(rows.map(\.type) == ["Internal", "External"])
        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    @Test("The login-qualified name wins, matching the wizard's chip")
    func prefersNameUserId() {
        let rows = TrainerDisplay.list(
            from: [item(name: "Chetan Wade", nameUserId: "Chetan Wade II-cw")],
            scheduleTrainerType: nil, fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.name) == ["Chetan Wade II-cw"])
    }

    @Test("A trainer with no type of its own inherits the schedule's type")
    func inheritsScheduleType() {
        let rows = TrainerDisplay.list(
            from: [item(type: nil)],
            scheduleTrainerType: "consultant", fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.type) == ["Consultant"])
    }

    @Test("No type anywhere leaves the badge off rather than guessing")
    func noTypeStaysNil() {
        let rows = TrainerDisplay.list(
            from: [item(type: nil)],
            scheduleTrainerType: nil, fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.type) == [nil])
    }

    @Test("Repeated trainer ids still produce distinct rows")
    func duplicateIdsStayDistinct() {
        let rows = TrainerDisplay.list(
            from: [item(id: 7, name: "A"), item(id: 7, name: "B")],
            scheduleTrainerType: nil, fallbackName: nil, fallbackType: nil
        )
        #expect(Set(rows.map(\.id)).count == 2)
    }

    @Test("Nameless entries are dropped")
    func dropsNamelessRows() {
        let rows = TrainerDisplay.list(
            from: [item(name: nil), item(name: "  "), item(name: "Kashif User")],
            scheduleTrainerType: nil, fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.name) == ["Kashif User"])
    }

    /// The card shows a type badge, so the "(External)" the server appends to `nameUserId`
    /// is dropped — otherwise the name reads the type twice and truncates.
    @Test("The type the server appends to the name is dropped, the badge carries it")
    func stripsTypeSuffixFromName() {
        let rows = TrainerDisplay.list(
            from: [item(name: "LMS Admin", type: "Internal", nameUserId: "LMS Admin-lmsadmin (Internal)")],
            scheduleTrainerType: nil, fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.name) == ["LMS Admin-lmsadmin"])
        #expect(rows.map(\.type) == ["Internal"])
    }

    @Test("A trailing suffix that is not a type stays on the name")
    func keepsNonTypeSuffix() {
        let rows = TrainerDisplay.list(
            from: [item(nameUserId: "Chetan Wadil (chetan.w)")],
            scheduleTrainerType: nil, fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.name) == ["Chetan Wadil (chetan.w)"])
    }

    @Test("The stand-in trainer name is cleaned up the same way")
    func stripsTypeSuffixFromFallbackName() {
        let rows = TrainerDisplay.list(
            from: [], scheduleTrainerType: nil,
            fallbackName: "Ram-8668946281 (External)", fallbackType: "External"
        )
        #expect(rows.map(\.name) == ["Ram-8668946281"])
        #expect(rows.map(\.type) == ["External"])
    }

    @Test("Without a trainer list the schedule's own trainer stands in")
    func fallsBackToScheduleTrainer() {
        for list in [nil, []] as [[EditScheduleDataModel.TrainerItem]?] {
            let rows = TrainerDisplay.list(
                from: list,
                scheduleTrainerType: nil,
                fallbackName: "Kashif User",
                fallbackType: "internal"
            )
            #expect(rows.map(\.name) == ["Kashif User"])
            #expect(rows.map(\.type) == ["Internal"])
        }
    }

    @Test("A schedule with no trainer shows no section")
    func emptyWhenNoTrainerAtAll() {
        #expect(TrainerDisplay.list(from: [], scheduleTrainerType: nil, fallbackName: nil, fallbackType: nil).isEmpty)
        #expect(TrainerDisplay.list(from: [], scheduleTrainerType: nil, fallbackName: "-", fallbackType: nil).isEmpty)
        #expect(TrainerDisplay.list(from: [], scheduleTrainerType: nil, fallbackName: "  ", fallbackType: nil).isEmpty)
    }

    /// The bug this pins: `GetScheduleDetailsByID` carries one `trainerType` for the whole
    /// schedule, so a mixed schedule badged every trainer with whichever type the organiser
    /// picked last ("External" for all three). Each trainer's own type arrives appended to
    /// its `nameUserId`, so that is what the badge reads.
    @Test("A mixed schedule keeps each trainer's own type, not the schedule's")
    func perTrainerTypeFromTheNameWinsOverTheScheduleType() {
        let rows = TrainerDisplay.list(
            from: [
                item(id: 1, name: "LMS Admin", type: nil, nameUserId: "LMS Admin-lmsadmin (Internal)"),
                item(id: 2, name: "kashif", type: nil, nameUserId: "kashif-kashif (Internal)"),
                item(id: 3, name: "Ram", type: nil, nameUserId: "Ram-8668946281 (External)"),
            ],
            scheduleTrainerType: "External",
            fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.name) == ["LMS Admin-lmsadmin", "kashif-kashif", "Ram-8668946281"])
        #expect(rows.map(\.type) == ["Internal", "Internal", "External"])
    }

    /// The row's own `trainerType` comes back flattened to the schedule's type on some
    /// schedules, so the name suffix — which is per-trainer — is trusted ahead of it.
    @Test("The name's type wins over a flattened row type")
    func nameSuffixWinsOverRowType() {
        let rows = TrainerDisplay.list(
            from: [item(type: "External", nameUserId: "kashif-kashif (Internal)")],
            scheduleTrainerType: "External", fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.type) == ["Internal"])
    }

    @Test("A name carrying no type falls back to the row's own type")
    func rowTypeStandsInWhenTheNameCarriesNone() {
        let rows = TrainerDisplay.list(
            from: [item(type: "consultant", nameUserId: "Asha-asha")],
            scheduleTrainerType: "External", fallbackName: nil, fallbackType: nil
        )
        #expect(rows.map(\.type) == ["Consultant"])
    }

    @Test("The stand-in trainer's type comes from its name too")
    func fallbackNameCarriesItsOwnType() {
        let rows = TrainerDisplay.list(
            from: [], scheduleTrainerType: "External",
            fallbackName: "kashif-kashif (Internal)", fallbackType: "External"
        )
        #expect(rows.map(\.name) == ["kashif-kashif"])
        #expect(rows.map(\.type) == ["Internal"])
    }

    @Test(arguments: [
        ("kashif-kashif (Internal)", "Internal"),
        ("Ram-8668946281 (external)", "External"),
        ("Asha (Consultant)", "Consultant"),
    ])
    func typeSuffixIsReadAndNormalized(name: String, expected: String) {
        #expect(TrainerType.typeSuffix(in: name) == expected)
    }

    @Test(arguments: ["Chetan Wadil (chetan.w)", "kashif-kashif", "(Internal)", "LMS Admin-lmsadmin ("])
    func aSuffixThatIsNotAKnownTypeReadsAsNoType(name: String) {
        #expect(TrainerType.typeSuffix(in: name) == nil)
    }
}

/// End-to-end over the real `GetScheduleDetailsByID` body for a mixed-type schedule
/// (SC9052): decodes the captured response and checks the badges the TRAINERS section
/// renders from it, so a decoding change cannot silently flatten the types again.
@Suite struct ScheduleDetailMixedTrainerTypesTests {

    private func details() throws -> EditScheduleDataModel.ScheduleDetailsResponse {
        try JSONDecoder().decode(
            EditScheduleDataModel.ScheduleDetailsResponse.self,
            from: Data(EditScheduleFixtures.mixedTrainerTypesDetailsJSON.utf8)
        )
    }

    @Test("The captured mixed-type response decodes with every trainer's own type")
    func responseDecodes() throws {
        let response = try details()
        #expect(response.trainerType == "Internal")
        #expect(response.trainerList?.map(\.trainerType) == ["Internal", "External", "Internal"])
        #expect(response.trainerList?.map(\.nameUserId) == [
            "LMS Admin-lmsadmin (Internal)", "Ram-8668946281 (External)", "kashif-kashif (Internal)"
        ])
    }

    @Test("Each card badges the trainer's own type, not the schedule's")
    func badgesArePerTrainer() throws {
        let response = try details()
        let rows = ScheduleDetailDataModel.TrainerDisplay.list(
            from: response.trainerList,
            scheduleTrainerType: response.trainerType,
            fallbackName: response.academyTrainerName,
            fallbackType: response.trainerType
        )
        #expect(rows.map(\.name) == ["LMS Admin-lmsadmin", "Ram-8668946281", "kashif-kashif"])
        #expect(rows.map(\.type) == ["Internal", "External", "Internal"])
    }
}
