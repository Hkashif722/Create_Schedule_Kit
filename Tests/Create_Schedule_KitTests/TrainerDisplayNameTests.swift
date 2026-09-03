//
//  TrainerDisplayNameTests.swift
//  Create_Schedule_KitTests
//
//  Pins the trainer chip display on the Venue step: the web client shows
//  "Chetan Wadil (Internal)", so the mobile chip composes the same suffix from
//  the trainer type. Selection stamps the wizard's selected Trainer Type because
//  the search endpoint does not reliably echo it.
//

import Foundation
import Testing
@testable import Create_Schedule_Kit

@Suite struct TrainerDisplayNameTests {

    private func trainer(
        name: String = "Chetan Wadil",
        userType: String?,
        nameUserId: String? = nil
    ) -> ScheduleLogisticsDataModel.Trainer {
        ScheduleLogisticsDataModel.Trainer(
            id: "enc-id",
            name: name,
            emailId: nil,
            userId: nil,
            profilePicture: nil,
            mobileNumber: nil,
            userType: userType,
            nameUserId: nameUserId
        )
    }

    @Test(arguments: [
        ("Internal", "Chetan Wadil (Internal)"),
        ("External", "Chetan Wadil (External)"),
        ("Consultant", "Chetan Wadil (Consultant)"),
    ])
    func nameComposesWithTheTrainerType(raw: String, expected: String) {
        #expect(trainer(userType: raw).displayNameWithType == expected)
    }

    /// Casing from the server is normalized through `TrainerType` so it matches the web.
    @Test func lowercasedTypeIsNormalized() {
        #expect(trainer(userType: "internal").displayNameWithType == "Chetan Wadil (Internal)")
    }

    /// A type outside the known three passes through untouched rather than being dropped.
    @Test func unknownTypePassesThrough() {
        #expect(trainer(userType: "Vendor").displayNameWithType == "Chetan Wadil (Vendor)")
    }

    @Test(arguments: [nil, "", "  "] as [String?])
    func missingTypeFallsBackToThePlainName(raw: String?) {
        #expect(trainer(userType: raw).displayNameWithType == "Chetan Wadil")
    }

    /// The composed `nameUserId` (when the server sends one) stays the base of the display.
    @Test func nameUserIdStaysTheBase() {
        let row = trainer(userType: "Internal", nameUserId: "Chetan Wadil (chetan.w)")
        #expect(row.displayNameWithType == "Chetan Wadil (chetan.w) (Internal)")
    }

    @Test func stampingReplacesTheTypeAndNothingElse() {
        let stamped = trainer(userType: nil).withUserType("Consultant")

        #expect(stamped.userType == "Consultant")
        #expect(stamped.id == "enc-id")
        #expect(stamped.name == "Chetan Wadil")
        #expect(stamped.displayNameWithType == "Chetan Wadil (Consultant)")
    }
}
