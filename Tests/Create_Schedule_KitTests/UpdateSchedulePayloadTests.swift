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

    /// A Teams schedule whose meeting row the server already owns. `meetingId` / `iCalUId`
    /// are what the server matches on, so they must come back untouched.
    private func teamsBase() throws -> EditScheduleDataModel.ScheduleDetailsResponse {
        let json = EditScheduleFixtures.detailsJSON
            .replacingOccurrences(of: "\"isWebinar\": false", with: "\"isWebinar\": true")
            .replacingOccurrences(of: "\"webinarType\": null", with: "\"webinarType\": \"Teams\"")
            .replacingOccurrences(
                of: "\"teamsScheduleDetails\": null",
                with: """
                "teamsScheduleDetails": [{
                    "id": 77, "courseID": 19372, "scheduleID": 3892,
                    "meetingId": "MEET-1", "startTime": null, "endTime": null,
                    "iCalUId": "ICAL-1", "joinUrl": "https://teams.microsoft.com/old",
                    "userWebinarId": 5
                }]
                """
            )
        return try JSONDecoder().decode(
            EditScheduleDataModel.ScheduleDetailsResponse.self,
            from: Data(json.utf8)
        )
    }

    // MARK: - Hand-entered Teams link (ATPTLWCS)

    /// Edit mode opens on the link the schedule already has, so the field is not blank.
    @Test func theDraftHydratesTheExistingJoinUrl() throws {
        let details = try teamsBase()

        #expect(hydratedDraft(from: details).teamsLink == "https://teams.microsoft.com/old")
    }

    /// An edited link replaces only `joinUrl`; the rest of the row is the server's own.
    @Test func anEditedLinkOverlaysTheFetchedMeetingRow() throws {
        let details = try teamsBase()
        let draft = hydratedDraft(from: details)
        draft.teamsLink = "https://teams.microsoft.com/new"

        let object = try encodeToObject(.init(base: details, draft: draft))
        let rows = try #require(object["teamsScheduleDetails"] as? [[String: Any]])

        #expect(rows.count == 1)
        #expect(rows[0]["joinUrl"] as? String == "https://teams.microsoft.com/new")
        #expect(rows[0]["id"] as? Int == 77)
        #expect(rows[0]["meetingId"] as? String == "MEET-1")
        #expect(rows[0]["iCalUId"] as? String == "ICAL-1")
        #expect(rows[0]["userWebinarId"] as? Int == 5)
    }

    /// A schedule with no meeting row yet gets one, carrying its own ids rather than the
    /// zeros the create body sends.
    @Test func aLinkOnASchedulesWithoutMeetingDetailsCreatesTheRow() throws {
        let details = try base()   // teamsScheduleDetails: null
        let draft = hydratedDraft(from: details)
        draft.webinarType = .teams
        draft.teamsLink = "https://teams.microsoft.com/fresh"

        let object = try encodeToObject(.init(base: details, draft: draft))
        let rows = try #require(object["teamsScheduleDetails"] as? [[String: Any]])

        #expect(rows.count == 1)
        #expect(rows[0]["joinUrl"] as? String == "https://teams.microsoft.com/fresh")
        #expect(rows[0]["scheduleID"] as? Int == 3892)
        #expect(rows[0]["courseID"] as? Int == 57812)
    }

    /// Nothing typed, or a provider that generates its own meeting: the fetched details
    /// go back exactly as they came, which is how this body has always behaved.
    @Test func theFetchedMeetingRowSurvivesWhenNoLinkWasTyped() throws {
        let details = try teamsBase()
        let draft = hydratedDraft(from: details)
        draft.teamsLink = nil

        let unedited = try encodeToObject(.init(base: details, draft: draft))
        let rows = try #require(unedited["teamsScheduleDetails"] as? [[String: Any]])
        #expect(rows[0]["joinUrl"] as? String == "https://teams.microsoft.com/old")

        // A Zoom schedule never overlays, even with a link left in the draft.
        draft.webinarType = .zoom
        draft.teamsLink = "https://teams.microsoft.com/new"
        let zoom = try encodeToObject(.init(base: details, draft: draft))
        let zoomRows = try #require(zoom["teamsScheduleDetails"] as? [[String: Any]])
        #expect(zoomRows[0]["joinUrl"] as? String == "https://teams.microsoft.com/old")
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

    /// A trainer added on top of the fetched schedule keeps the type it was picked under,
    /// even when the wizard's segmented control has since moved on.
    @Test func addedTrainerKeepsItsOwnTypeNotTheSelectedSegment() throws {
        let details = try base()
        let draft = hydratedDraft(from: details)
        draft.trainerType = .consultant
        draft.trainers.append(
            .init(id: "8999", name: "Ram", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "External", nameUserId: "Ram-8668946281 (External)")
        )

        let object = try encodeToObject(.init(base: details, draft: draft))
        let trainers = try #require(object["trainerList"] as? [[String: Any]])

        #expect(trainers.count == 2)
        // The pre-existing trainer is echoed verbatim from the base…
        #expect(trainers[0]["trainerType"] as? String == "Internal")
        // …and the new one carries its own type, not the selected "Consultant" segment.
        #expect(trainers[1]["trainerType"] as? String == "External")
        #expect(object["trainerType"] as? String == "Consultant")
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

    // MARK: - Teams meeting looked up by schedule code

    /// The row `GetTeamsMeetingByScheduleCode` answers, verbatim from UAT.
    private static let teamsMeetingJSON = """
    [{"username":null,"id":2375,"courseID":59207,"scheduleID":4493,"meetingId":"MeetingId",
      "startTime":"2026-09-08T18:55:00","endTime":"2026-09-08T18:59:00","iCalUId":null,
      "joinUrl":"Https://team.com","userWebinarId":0,"createdBy":9868,"modifiedBy":9868,
      "createdDate":"2026-09-08T18:56:49.9939539","modifiedDate":"2026-09-08T18:56:49.9939543",
      "isDeleted":false,"isActive":true}]
    """

    private func teamsMeeting() throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(Self.teamsMeetingJSON.utf8))
    }

    @Test func theTeamsMeetingLookupMatchesItsContract() {
        let request = EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest()

        #expect(request.path == "/api/v1/ILTSchedule/GetTeamsMeetingByScheduleCode")
        #expect(request.method == .post)
    }

    /// The lookup must never fire for another provider — Teams is the only one with a
    /// hand-entered link, and every other provider's meeting details belong to the server.
    @Test(arguments: [WebinarType.zoom, .googleMeet, .gotoMeeting])
    func theLookupIsSkippedForEveryOtherProvider(_ type: WebinarType) {
        let code = EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest.lookupCode(
            webinarType: type, scheduleCode: "SC9184"
        )
        #expect(code == nil)
    }

    @Test func theLookupIsSkippedWhenNoProviderIsSet() {
        // Offline schedules and anything the response's `webinarType` did not resolve.
        #expect(EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest.lookupCode(
            webinarType: nil, scheduleCode: "SC9184"
        ) == nil)
    }

    @Test func theLookupRunsForTeams() {
        #expect(EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest.lookupCode(
            webinarType: .teams, scheduleCode: "SC9184"
        ) == "SC9184")
    }

    @Test(arguments: [nil, "", "   "] as [String?])
    func theLookupIsSkippedWithoutAScheduleCode(_ scheduleCode: String?) {
        // Nothing to look up by, so the request would be meaningless.
        #expect(EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest.lookupCode(
            webinarType: .teams, scheduleCode: scheduleCode
        ) == nil)
    }

    @Test func theLookupBodyCarriesOnlyTheCode() throws {
        let payload = EditScheduleDataModel.GetTeamsMeetingByScheduleCodeRequest.Payload(code: "SC9184")
        let data = try JSONEncoder().encode(payload)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object.count == 1)
        #expect(object["Code"] as? String == "SC9184")
    }

    @Test func theStoredLinkIsReadOffTheLookupResponse() throws {
        #expect(try teamsMeeting().firstString(forKey: "joinUrl") == "Https://team.com")
    }

    @Test func updatingEchoesTheFetchedRowWithOnlyTheLinkReplaced() throws {
        let details = try base()
        let draft = hydratedDraft(from: details)
        draft.webinarType = .teams
        draft.teamsMeeting = try teamsMeeting()
        draft.teamsLink = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_NEW"

        let object = try encodeToObject(.init(base: details, draft: draft))
        let rows = try #require(object["teamsScheduleDetails"] as? [[String: Any]])
        let row = try #require(rows.first)

        // The new link…
        #expect(row["joinUrl"] as? String == "https://teams.microsoft.com/l/meetup-join/19%3ameeting_NEW")
        // …and the meeting's own identity, so the server updates this meeting rather than
        // creating a second one.
        #expect(row["id"] as? Int == 2375)
        #expect(row["meetingId"] as? String == "MeetingId")
        #expect(row["scheduleID"] as? Int == 4493)
        #expect(row["courseID"] as? Int == 59207)
        // Every other key the server sent survives the round trip.
        #expect(row["createdBy"] as? Int == 9868)
        #expect(row["isActive"] as? Bool == true)
        #expect(row["isDeleted"] as? Bool == false)
        #expect(row["startTime"] as? String == "2026-09-08T18:55:00")
    }

    @Test func theFetchedRowIsEchoedUntouchedWhenNoLinkWasEdited() throws {
        let details = try base()
        let draft = hydratedDraft(from: details)
        draft.webinarType = .teams
        draft.teamsMeeting = try teamsMeeting()
        draft.teamsLink = nil

        let object = try encodeToObject(.init(base: details, draft: draft))
        let rows = try #require(object["teamsScheduleDetails"] as? [[String: Any]])

        #expect(rows.first?["joinUrl"] as? String == "Https://team.com")
    }

    @Test func aFetchedRowForAnotherProviderIsStillEchoedUntouched() throws {
        // Provider switched away from Teams: the link must not be written into the row.
        let details = try base()
        let draft = hydratedDraft(from: details)
        draft.webinarType = .zoom
        draft.teamsMeeting = try teamsMeeting()
        draft.teamsLink = "https://team.link"

        let object = try encodeToObject(.init(base: details, draft: draft))
        let rows = try #require(object["teamsScheduleDetails"] as? [[String: Any]])

        #expect(rows.first?["joinUrl"] as? String == "Https://team.com")
    }
}
