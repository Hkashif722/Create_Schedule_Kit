import Testing
import Foundation
import SwiftUIUtilities
@testable import Create_Schedule_Kit

/// Encoding tests for the `ILTSchedule/UpdateILTScheduleWithMeeting` echo-back body:
/// fetched base fields survive verbatim, draft edits overlay them, and the duplicated
/// legacy keys (`moduleId`/`moduleID`, `trainerList`/`TrainerList`, `tagList`/`Taglist`,
/// `agencyTrainerName`/`AgencyTrainerName`) are all present.
@Suite struct UpdateSchedulePayloadTests {

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

    private func base() throws -> EditScheduleDataModel.ScheduleDetailsResponse {
        try JSONDecoder().decode(
            EditScheduleDataModel.ScheduleDetailsResponse.self,
            from: Data(EditScheduleFixtures.detailsJSON.utf8)
        )
    }

    /// Draft hydrated from the fixture, exactly as the wizard does it in edit mode.
    private func hydratedDraft(from details: EditScheduleDataModel.ScheduleDetailsResponse) -> ScheduleDraft {
        let draft = ScheduleDraft()
        draft.apply(details: details, modules: [], timezones: [])
        return draft
    }

    private func encodeToObject(_ payload: EditScheduleDataModel.UpdatePayload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return try #require(object as? [String: Any])
    }

    private func day(_ string: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)!
    }

    @Test func unchangedDraftEchoesTheFetchedSchedule() throws {
        let details = try base()
        let payload = EditScheduleDataModel.UpdatePayload(base: details, draft: hydratedDraft(from: details))
        let object = try encodeToObject(payload)

        // Identity.
        #expect(object["id"] as? Int == 3892)
        #expect(object["scheduleCode"] as? String == "SC6821")
        #expect(object["moduleId"] as? Int == 46111)
        #expect(object["moduleID"] as? Int == 46111)
        #expect(object["courseID"] as? Int == 57812)
        #expect(object["moduleName"] as? String == "19372_Schedule Creation")

        // Dates re-encoded in the update format, times back to 24-hour.
        #expect(object["startDate"] as? String == "2026-08-04T00:00:00.000Z")
        #expect(object["endDate"] as? String == "2026-08-04T00:00:00.000Z")
        #expect(object["registrationEndDate"] as? String == "2026-08-04T00:00:00.000Z")
        #expect(object["startTime"] as? String == "19:10")
        #expect(object["endTime"] as? String == "19:12")

        // Venue from the hydrated place.
        #expect(object["placeID"] as? Int == 8)
        #expect(object["placeName"] as? String == "Mumbai")
        #expect(object["city"] as? String == "Mumbai")
        #expect(object["seatCapacity"] as? String == "100")
        #expect(object["scheduleCapacity"] as? Int == 100)
        #expect(object["postalAddress"] as? String == "J W Marriott Dadar West")
        #expect(object["placeType"] as? String == "Internal")
        #expect(object["academyAgencyID"] as? Int == 28)
        #expect(object["academyAgencyName"] as? String == "Mumbai")

        // Unchanged trainer echoed VERBATIM from the base (opaque encrypted email intact).
        let trainerList = try #require(object["trainerList"] as? [[String: Any]])
        let trainerListDup = try #require(object["TrainerList"] as? [[String: Any]])
        #expect(trainerList.count == 1)
        #expect(trainerListDup.count == 1)
        #expect(trainerList[0]["academyTrainerID"] as? Int == 8973)
        #expect(trainerList[0]["trainerEmail"] as? String == "kodV1wwpC1fAiTRuK2jifcKuE9h5S1AXqBAr2D1V05o=")
        #expect(trainerList[0]["nameUserId"] as? String == "kashif-kashif (Internal)")

        // Holidays regenerated for the range.
        let holidays = try #require(object["holidayList"] as? [[String: Any]])
        #expect(holidays.count == 1)
        #expect(holidays[0]["date"] as? String == "2026-08-04")
        #expect(holidays[0]["isHoliday"] as? Bool == false)
        #expect(holidays[0]["reason"] as? String == "Work Day")

        // Duplicated legacy keys.
        #expect(object.keys.contains("tagList"))
        #expect(object.keys.contains("Taglist"))
        #expect(object["agencyTrainerName"] is NSNull)
        #expect(object["AgencyTrainerName"] is NSNull)

        // Pass-through metadata echoed verbatim.
        #expect(object["purpose"] as? String == "Planned Training")
        #expect(object["scheduleType"] as? String == "Scheduled")
        #expect(object["status"] as? Bool == true)
        #expect(object["isActive"] as? Bool == true)
        #expect(object["isDeleted"] as? Bool == false)
        #expect(object["timezone"] as? String == "India Standard Time")
        #expect(object["createdBy"] as? String == "LMS Admin")
        #expect(object["createdDate"] as? String == "03-08-2026 07:11 PM")
        #expect(object["record"] as? Bool == false)
        #expect(object["cost"] as? Double == 0)
        #expect(object["teamsScheduleDetails"] is NSNull)
        #expect(object["topicList"] as? [Any] != nil)

        // No feedback on the fixture.
        #expect(object["isFeedback"] as? Bool == false)
        #expect(object["feedbackId"] is NSNull)
        #expect(object["isWebinar"] as? Bool == false)
    }

    @Test func draftEditsOverlayTheBase() throws {
        let details = try base()
        let draft = hydratedDraft(from: details)

        // Edits a user could make in the wizard.
        draft.startDate = day("2026-08-10")
        draft.endDate = day("2026-08-11")
        draft.registrationEndDate = day("2026-08-09")
        draft.startTime = "09:30"   // apiTime passes 24h strings through unchanged
        draft.endTime = "11:45"
        draft.tags = [
            .init(id: 7, tag: "Sony", tagCode: nil, isActive: nil),
            .init(id: 8, tag: "Carrier", tagCode: nil, isActive: nil)
        ]
        draft.coordinatorName = "kashif"
        draft.contactNumber = "7498578961"
        draft.feedbackModule = .init(id: "42111", title: "Feedback Report", category: nil)
        draft.trainingPlace = .init(
            id: 9, placeCode: nil, cityname: "Pune", placeName: "Pune HQ",
            accommodationCapacity: "50", postalAddress: "Karve Nagar",
            contactNumber: nil, contactPerson: nil
        )

        let object = try encodeToObject(.init(base: details, draft: draft))

        #expect(object["startDate"] as? String == "2026-08-10T00:00:00.000Z")
        #expect(object["endDate"] as? String == "2026-08-11T00:00:00.000Z")
        #expect(object["registrationEndDate"] as? String == "2026-08-09T00:00:00.000Z")
        #expect(object["startTime"] as? String == "09:30")
        #expect(object["endTime"] as? String == "11:45")

        // New venue overlays the base one.
        #expect(object["placeID"] as? Int == 9)
        #expect(object["placeName"] as? String == "Pune HQ")
        #expect(object["city"] as? String == "Pune")
        #expect(object["seatCapacity"] as? String == "50")
        #expect(object["scheduleCapacity"] as? Int == 50)

        // Coordinator + contact carry the real edited values (create nils these).
        #expect(object["contactPersonName"] as? String == "kashif")
        #expect(object["contactNumber"] as? String == "7498578961")

        // Tags mirrored under both keys.
        let tags = try #require(object["tagList"] as? [[String: Any]])
        let tagsDup = try #require(object["Taglist"] as? [[String: Any]])
        #expect(tags.map { $0["tagId"] as? Int } == [7, 8])
        #expect(tagsDup.map { $0["tag"] as? String } == ["Sony", "Carrier"])

        // Feedback attached.
        #expect(object["isFeedback"] as? Bool == true)
        #expect(object["feedbackId"] as? Int == 42111)
        #expect(object["feedbackName"] as? String == "Feedback Report")

        // Two-day range regenerates two holiday rows.
        let holidays = try #require(object["holidayList"] as? [[String: Any]])
        #expect(holidays.count == 2)

        // Identity still echoes the base.
        #expect(object["id"] as? Int == 3892)
        #expect(object["courseName"] as? String == "Schedule Creation")
    }

    @Test func newlyAddedTrainerIsBuiltFromSearchResult() throws {
        let details = try base()
        let draft = hydratedDraft(from: details)
        // A trainer picked from the search dropdown (encrypted id the utility can't
        // decrypt with the stub key falls back to 0 — still exercises the build path).
        draft.trainers.append(
            .init(id: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "10101"),
                  name: "Kashif", emailId: "ENC_EMAIL==", userId: nil,
                  profilePicture: nil, mobileNumber: nil, userType: "Internal",
                  nameUserId: "Kashif (Internal)")
        )

        let object = try encodeToObject(.init(base: details, draft: draft))
        let trainers = try #require(object["trainerList"] as? [[String: Any]])
        #expect(trainers.count == 2)

        // Existing trainer echoed verbatim.
        #expect(trainers[0]["academyTrainerID"] as? Int == 8973)
        #expect(trainers[0]["trainerEmail"] as? String == "kodV1wwpC1fAiTRuK2jifcKuE9h5S1AXqBAr2D1V05o=")

        // New trainer built like the create payload does.
        #expect(trainers[1]["academyTrainerID"] as? Int == 10101)
        #expect(trainers[1]["academyTrainerName"] as? String == "Kashif")
        #expect(trainers[1]["emailID"] as? String == "ENC_EMAIL==")
        #expect(trainers[1]["trainerEmail"] as? String == "ENC_EMAIL==")
        #expect(trainers[1]["nameUserId"] as? String == "Kashif (Internal)")
    }
}
