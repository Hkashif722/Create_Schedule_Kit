//
//  TrainingPlaceTypeTests.swift
//  Create_Schedule_KitTests
//
//  The Venue step's "Training place type" (sent as `placeType`). Internal venues belong to
//  an academy picked from the directory (`academyAgencyId` + name); External ones to an
//  agency that has no directory, so only a typed `academyAgencyName` goes out — matching the
//  web client, which swaps the same field between "Academy Name" and "Agency Name".
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct TrainingPlaceTypeTests {

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

    // MARK: - Draft → create payload

    private func draft() -> ScheduleDraft {
        let draft = ScheduleDraft()
        draft.module = .init(id: 17884, title: "5351_schedule request check2", type: "classroom",
                             courseFee: 0, currency: "", category: nil, subCategory: nil, subSubCategory: nil)
        draft.course = .init(id: 17136, title: "schedule request check2", code: "5351")
        draft.trainingPlace = .init(id: 112, placeCode: nil, cityname: "Goa", placeName: "GOA",
                                    accommodationCapacity: "5", postalAddress: "Goa",
                                    contactNumber: nil, contactPerson: nil)
        return draft
    }

    private func encodeToObject(_ payload: CreateScheduleWizardDataModel.Payload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func internalVenueSendsTheAcademyIdAndName() throws {
        let draft = draft()
        draft.placeType = .internal
        draft.academy = .init(id: 89, title: "PUNER", type: nil)
        draft.agencyName = "typed but not used"

        let object = try encodeToObject(.init(draft: draft))
        #expect(object["placeType"] as? String == "Internal")
        #expect(object["academyAgencyId"] as? Int == 89)
        #expect(object["academyAgencyName"] as? String == "PUNER")
    }

    /// Mirrors the UAT payload for an external venue: no agency id, the typed name, and
    /// `placeType: "External"`.
    @Test func externalVenueSendsTheTypedAgencyNameWithNoId() throws {
        let draft = draft()
        draft.placeType = .external
        draft.academy = .init(id: 89, title: "PUNER", type: nil)   // stale internal pick
        draft.agencyName = "  agency name  "

        let object = try encodeToObject(.init(draft: draft))
        #expect(object["placeType"] as? String == "External")
        #expect(object["academyAgencyId"] is NSNull)
        #expect(object["academyAgencyName"] as? String == "agency name")
    }

    @Test func anEmptyAgencyNameIsSentAsNullRatherThanBlank() throws {
        let draft = draft()
        draft.placeType = .external
        draft.agencyName = "   "

        let object = try encodeToObject(.init(draft: draft))
        #expect(object["academyAgencyName"] is NSNull)
    }

    // MARK: - Edit round-trip

    private func details(placeType: String?, agencyID: Int?, agencyName: String?) throws
    -> EditScheduleDataModel.ScheduleDetailsResponse {
        var json = EditScheduleFixtures.detailsJSON
        json = json.replacingOccurrences(of: "\"placeType\": \"Internal\"",
                                         with: "\"placeType\": \(placeType.map { "\"\($0)\"" } ?? "null")")
        json = json.replacingOccurrences(of: "\"academyAgencyID\": 28",
                                         with: "\"academyAgencyID\": \(agencyID.map(String.init) ?? "null")")
        json = json.replacingOccurrences(of: "\"academyAgencyName\": \"Mumbai\"",
                                         with: "\"academyAgencyName\": \(agencyName.map { "\"\($0)\"" } ?? "null")")
        return try JSONDecoder().decode(
            EditScheduleDataModel.ScheduleDetailsResponse.self,
            from: Data(json.utf8)
        )
    }

    @Test func editingAnExternalScheduleHydratesTheTypedAgencyName() throws {
        let details = try details(placeType: "External", agencyID: nil, agencyName: "agency name")
        let draft = ScheduleDraft()
        draft.apply(details: details, modules: [], timezones: [])

        #expect(draft.placeType == .external)
        #expect(draft.agencyName == "agency name")
        #expect(draft.academy == nil)
    }

    @Test func editingAnInternalScheduleStillHydratesTheAcademy() throws {
        let details = try details(placeType: "Internal", agencyID: 28, agencyName: "Mumbai")
        let draft = ScheduleDraft()
        draft.apply(details: details, modules: [], timezones: [])

        #expect(draft.placeType == .internal)
        #expect(draft.academy?.id == 28)
        #expect(draft.agencyName.isEmpty)
    }

    @Test func anUnknownOrMissingPlaceTypeReadsAsInternal() throws {
        #expect(TrainingPlaceType(apiValue: nil) == .internal)
        #expect(TrainingPlaceType(apiValue: "") == .internal)
        #expect(TrainingPlaceType(apiValue: "Hybrid") == .internal)
        #expect(TrainingPlaceType(apiValue: "external") == .external)
        #expect(TrainingPlaceType(apiValue: " External ") == .external)
    }

    /// Switching an existing internal schedule to External must not leave the old academy id
    /// in the update body — the server would keep treating the venue as academy-owned.
    @Test func switchingToExternalOnUpdateDropsTheStoredAcademyId() throws {
        let details = try details(placeType: "Internal", agencyID: 28, agencyName: "Mumbai")
        let draft = ScheduleDraft()
        draft.apply(details: details, modules: [], timezones: [])
        draft.placeType = .external
        draft.agencyName = "agency name"

        let data = try JSONEncoder().encode(EditScheduleDataModel.UpdatePayload(base: details, draft: draft))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["placeType"] as? String == "External")
        #expect(object["academyAgencyID"] is NSNull)
        #expect(object["academyAgencyName"] as? String == "agency name")
    }

    // MARK: - Step validation

    @MainActor
    private func viewModel(_ draft: ScheduleDraft) -> ScheduleLogisticsViewModel {
        ScheduleLogisticsViewModel(
            router: RouterEnvironmentKey.defaultValue,
            draft: draft,
            onBack: {},
            onContinue: {}
        )
    }

    @MainActor
    @Test func theOwnerFieldIsRequiredAndNamedAfterTheVenueType() {
        let model = viewModel(draft())

        #expect(model.validationMessage == "Select an academy name.")
        model.didSelectPlaceType(.external)
        #expect(model.validationMessage == "Enter an agency name.")

        model.agencyName = "   "
        #expect(model.validationMessage == "Enter an agency name.")
        model.agencyName = "agency name"
        #expect(model.validationMessage == "Add at least one trainer.")
        #expect(!model.canContinue)
    }

    @MainActor
    @Test func switchingTypeKeepsWhatWasAlreadyFilledInOnEachSide() {
        let draft = draft()
        draft.academy = .init(id: 89, title: "PUNER", type: nil)
        let model = viewModel(draft)

        model.agencyName = "agency name"
        model.didSelectPlaceType(.external)
        #expect(model.selectedAcademy?.id == 89)
        model.didSelectPlaceType(.internal)
        #expect(model.agencyName == "agency name")
        #expect(model.validationMessage == "Select a training place." || model.validationMessage == "Add at least one trainer.")
    }
}
