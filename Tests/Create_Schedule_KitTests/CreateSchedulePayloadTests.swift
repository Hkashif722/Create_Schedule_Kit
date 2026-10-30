import Testing
import Foundation
import SwiftUIUtilities
@testable import Create_Schedule_Kit

/// Encoding tests for the `ILTSchedule/PostWithMeeting` request body. These pin the exact
/// key casing, conditional webinar keys, Taglist shape, ISO dates and holiday mapping against
/// the known-good web payloads.
@Suite struct CreateSchedulePayloadTests {

    typealias DM = CreateScheduleWizardDataModel

    init() {
        // The trainer-id decrypt path reads the shared utility environment, which must be
        // configured before use (matches the views' preview setup).
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

    private func encodeToObject(_ payload: DM.Payload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return try #require(object as? [String: Any])
    }

    /// `2026-06-24` in the current time zone → the Date the picker would have produced.
    private func day(_ string: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)!
    }

    private func offlineDraft() -> ScheduleDraft {
        let draft = ScheduleDraft()
        draft.scheduleCode = "SC6562"
        draft.course = .init(id: 19825, title: "Test ILT006", code: "ILT006")
        draft.module = .init(id: 19785, title: "8729_Test ILT006", type: "classroom",
                             courseFee: 0, currency: "", category: nil, subCategory: nil, subSubCategory: nil)
        draft.deliveryMode = .offline
        draft.trainerType = .internal
        draft.academy = .init(id: 89, title: "PUNER", type: nil)
        draft.trainingPlace = .init(id: 5, placeCode: nil, cityname: "pune", placeName: "pune",
                                    accommodationCapacity: "100",
                                    postalAddress: "Karve Nagar\nDatt Digambar Colony\nWarje naka",
                                    contactNumber: "123", contactPerson: "Ravi")
        draft.tags = [
            .init(id: 7, tag: "Sony", tagCode: nil, isActive: false),
            .init(id: 10, tag: "Enthral", tagCode: nil, isActive: false)
        ]
        draft.startDate = day("2026-06-24")
        draft.endDate = day("2026-06-24")
        draft.registrationEndDate = day("2026-06-24")
        draft.startTime = "16:47"
        draft.endTime = "16:48"
        draft.timezone = .init(value: "India Standard Time", code: "IST", offset: 5.5, isdst: false, name: "IST")
        return draft
    }

    @Test func offlinePayloadMatchesSample() throws {
        let object = try encodeToObject(.init(draft: offlineDraft()))

        #expect(object["scheduleCode"] as? String == "SC6562")
        #expect(object["moduleID"] as? Int == 19785)
        #expect(object["courseID"] as? Int == 19825)
        #expect(object["courseName"] as? String == "Test ILT006")
        #expect(object["trainerType"] as? String == "Internal")
        #expect(object["academyAgencyId"] as? Int == 89)
        #expect(object["academyAgencyName"] as? String == "PUNER")
        #expect(object["city"] as? String == "pune")
        #expect(object["seatCapacity"] as? String == "100")
        #expect(object["scheduleCapacity"] as? Int == 100)
        #expect(object["placeID"] as? Int == 5)
        #expect(object["placeType"] as? String == "Internal")
        #expect(object["purpose"] as? String == "Planned Training")
        #expect(object["timezone"] as? String == "India Standard Time")
        #expect(object["startTime"] as? String == "16:47")
        #expect(object["endTime"] as? String == "16:48")
        #expect(object["startDate"] as? String == "2026-06-24T00:00:00.000Z")
        #expect(object["registrationEndDate"] as? String == "2026-06-24T00:00:00.000Z")

        // Offline ⇒ no webinar keys at all.
        #expect(object["isWebinar"] as? Bool == false)
        #expect(object["webinarType"] == nil)
        #expect(object["webinarAccount"] == nil)

        // No feedback ⇒ explicit nulls.
        #expect(object["isFeedback"] is NSNull)
        #expect(object["feedbackId"] is NSNull)

        // Exact-cased / always-null keys present.
        #expect(object["batchCode"] is NSNull)
        #expect(object["AgencyTrainerName"] is NSNull)
        #expect(object["contactPersonName"] is NSNull)
        #expect(object.keys.contains("Taglist"))
        #expect(object.keys.contains("TrainerList"))

        let tags = try #require(object["Taglist"] as? [[String: Any]])
        #expect(tags.count == 2)
        #expect(tags[0]["tagId"] as? Int == 7)
        #expect(tags[0]["tag"] as? String == "Sony")

        // One holiday row per day in range, working day mapped to "Work Day".
        let holidays = try #require(object["holidayList"] as? [[String: Any]])
        #expect(holidays.count == 1)
        #expect(holidays[0]["date"] as? String == "2026-06-24")
        #expect(holidays[0]["isHoliday"] as? Bool == false)
        #expect(holidays[0]["reason"] as? String == "Work Day")
    }

    /// The server's `scheduleCapacity` is an `Int32`: an empty string came back as a 400
    /// ("Error converting value {null} to type 'System.Int32'").
    @Test func aPlaceWithoutCapacitySendsZeroScheduleCapacity() throws {
        for capacity in [nil, "", "  "] as [String?] {
            let draft = offlineDraft()
            draft.trainingPlace = .init(id: 11, placeCode: nil, cityname: "Compass India",
                                        placeName: "Compass India", accommodationCapacity: capacity,
                                        postalAddress: nil, contactNumber: nil, contactPerson: nil)
            let object = try encodeToObject(.init(draft: draft))
            #expect(object["scheduleCapacity"] as? Int == 0)
        }
    }

    @Test func webinarPayloadEmitsConditionalKeysAndFeedback() throws {
        let draft = offlineDraft()
        draft.deliveryMode = .online
        draft.webinarType = .zoom
        draft.credential = [.init(id: 1043, teamsEmail: "ENC_ACCOUNT==", username: nil, password: nil, isDefault: 0)]
        draft.feedbackModule = .init(id: "42111", title: "Feedback Report", category: "data")
        draft.trainers = [
            // id is the value EncryptDecryptUtility would decrypt to a number; with a non-decryptable
            // stub it falls back to 0, which still exercises the mapping shape.
            .init(id: "8977", name: "Lms Demo ", emailId: "ENC_EMAIL==", userId: nil,
                  profilePicture: nil, mobileNumber: nil, userType: "Internal",
                  nameUserId: "Lms Demo  - zivame (Internal)")
        ]

        let object = try encodeToObject(.init(draft: draft))

        #expect(object["isWebinar"] as? Bool == true)
        #expect(object["webinarType"] as? String == "zoom")
        #expect(object["webinarAccount"] as? String == "ENC_ACCOUNT==")
        #expect(object["isFeedback"] as? Bool == true)
        #expect(object["feedbackId"] as? Int == 42111)

        let trainers = try #require(object["TrainerList"] as? [[String: Any]])
        #expect(trainers.count == 1)
        #expect(trainers[0]["academyTrainerName"] as? String == "Lms Demo ")
        #expect(trainers[0]["trainerType"] as? String == "Internal")
        #expect(trainers[0]["nameUserId"] as? String == "Lms Demo  - zivame (Internal)")
        #expect(trainers[0]["emailID"] as? String == "ENC_EMAIL==")
        #expect(trainers[0]["trainerEmail"] as? String == "ENC_EMAIL==")
        #expect(trainers[0]["academyTrainerID"] != nil)
    }

    /// Each trainer is saved with the type it was added under. The wizard's segmented control
    /// can be switched between trainers, so sending `draft.trainerType` for every row marked a
    /// mixed list as all-External (whichever segment was last selected) — which is what the
    /// Schedule Details trainer badges then showed.
    @Test func trainersKeepTheirOwnTypeInsteadOfTheLastSelectedSegment() throws {
        let draft = offlineDraft()
        draft.trainerType = .external   // last segment the user touched
        draft.trainers = [
            .init(id: "1", name: "Lms Admin", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "Internal", nameUserId: "LMS Admin-lmsadmin (Internal)"),
            .init(id: "2", name: "Ram", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "External", nameUserId: "Ram-8668946281 (External)"),
            .init(id: "3", name: "Asha", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "consultant", nameUserId: "Asha-asha"),
            // No stamped type (older draft state) — the wizard's own type stands in.
            .init(id: "4", name: "Kiran", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: nil, nameUserId: "Kiran-kiran")
        ]

        let object = try encodeToObject(.init(draft: draft))
        let trainers = try #require(object["TrainerList"] as? [[String: Any]])

        #expect(trainers.map { $0["trainerType"] as? String } == ["Internal", "External", "Consultant", "External"])
        // The schedule's own type is still the wizard's selection.
        #expect(object["trainerType"] as? String == "External")
    }

    /// The web client appends each trainer's own type to `nameUserId`
    /// ("LMS Admin - lmsadmin (Internal)") — `searchTrainer` returns the composed name
    /// without it. The server echoes the string back on `GetScheduleDetailsByID`, where
    /// Schedule Details reads the badge from it, so the suffix must match the row's
    /// `trainerType` for every trainer on a mixed schedule.
    @Test func nameUserIdCarriesEachTrainersOwnType() throws {
        let draft = offlineDraft()
        draft.trainerType = .external
        draft.trainers = [
            .init(id: "1", name: "LMS Admin", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "Internal", nameUserId: "LMS Admin - lmsadmin"),
            .init(id: "2", name: "Ram", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "External", nameUserId: "Ram - 8668946281"),
            // No composed name from the server — the plain name carries the suffix instead.
            .init(id: "3", name: "Asha", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "consultant", nameUserId: nil),
            // No stamped type — name and `trainerType` both fall back to the wizard's type.
            .init(id: "4", name: "Kiran", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: nil, nameUserId: "Kiran - kiran")
        ]

        let object = try encodeToObject(.init(draft: draft))
        let trainers = try #require(object["TrainerList"] as? [[String: Any]])

        #expect(trainers.map { $0["nameUserId"] as? String } == [
            "LMS Admin - lmsadmin (Internal)",
            "Ram - 8668946281 (External)",
            "Asha (Consultant)",
            "Kiran - kiran (External)"
        ])
        // The suffix and the row's own type always agree.
        #expect(trainers.map { $0["trainerType"] as? String } == ["Internal", "External", "Consultant", "External"])
    }

    /// A type the server already appended is not doubled up.
    @Test func anAlreadySuffixedNameIsNotSuffixedTwice() throws {
        let draft = offlineDraft()
        draft.trainers = [
            .init(id: "1", name: "kashif", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "Internal", nameUserId: "kashif - kashif (Internal)")
        ]
        let trainers = try #require(try encodeToObject(.init(draft: draft))["TrainerList"] as? [[String: Any]])
        #expect(trainers.first?["nameUserId"] as? String == "kashif - kashif (Internal)")
    }

    /// `searchTrainer` returns the address encrypted; the web sends it in the clear and the
    /// server stores what it is given, so the payload decrypts it first.
    @Test func trainerEmailIsSentDecrypted() throws {
        let draft = offlineDraft()
        let encrypted = EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "lmsadmin11@enthral.com")
        draft.trainers = [
            .init(id: "1", name: "LMS Admin", emailId: encrypted, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "Internal", nameUserId: "LMS Admin - lmsadmin")
        ]

        let trainers = try #require(try encodeToObject(.init(draft: draft))["TrainerList"] as? [[String: Any]])
        #expect(encrypted != "lmsadmin11@enthral.com")
        #expect(trainers.first?["emailID"] as? String == "lmsadmin11@enthral.com")
        #expect(trainers.first?["trainerEmail"] as? String == "lmsadmin11@enthral.com")
    }

    /// An address that does not decrypt is sent as-is rather than blanked, and a trainer
    /// with no address on file still sends the empty string the body has always carried.
    @Test func anUndecryptableOrMissingEmailIsSafe() throws {
        let draft = offlineDraft()
        draft.trainers = [
            .init(id: "1", name: "Plain", emailId: "plain@enthral.com", userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "Internal", nameUserId: nil),
            .init(id: "2", name: "None", emailId: nil, userId: nil, profilePicture: nil,
                  mobileNumber: nil, userType: "Internal", nameUserId: nil)
        ]

        let trainers = try #require(try encodeToObject(.init(draft: draft))["TrainerList"] as? [[String: Any]])
        #expect(trainers.map { $0["emailID"] as? String } == ["plain@enthral.com", ""])
    }

    // MARK: - Teams static link

    private func onlineDraft(_ type: WebinarType) -> ScheduleDraft {
        let draft = offlineDraft()
        draft.deliveryMode = .online
        draft.webinarType = type
        draft.credential = [.init(id: 1043, teamsEmail: "ENC_ACCOUNT==", username: nil, password: nil, isDefault: 0)]
        return draft
    }

    @Test func aTeamsScheduleSendsTheWebsWebinarType() throws {
        let object = try encodeToObject(.init(draft: onlineDraft(.teams)))
        #expect(object["webinarType"] as? String == "TEAMS")
    }

    @Test func aGoogleMeetScheduleSendsTheWebsWebinarType() throws {
        let object = try encodeToObject(.init(draft: onlineDraft(.googleMeet)))
        #expect(object["webinarType"] as? String == "googlemeet")
        // The account still identifies the meeting host, as the captured body shows.
        #expect(object["webinarAccount"] as? String == "ENC_ACCOUNT==")
    }

    @Test func teamsStaticLinkTravelsInTeamsScheduleDetails() throws {
        let draft = onlineDraft(.teams)
        draft.teamsLink = "Https://team.link"

        let object = try encodeToObject(.init(draft: draft))
        let details = try #require(object["teamsScheduleDetails"] as? [[String: Any]])

        #expect(details.count == 1)
        #expect(details[0]["joinUrl"] as? String == "Https://team.link")
        // The server's own scaffolding, reproduced exactly as the web client sends it.
        #expect(details[0]["id"] as? Int == 0)
        #expect(details[0]["courseID"] as? Int == 0)
        #expect(details[0]["scheduleID"] as? Int == 0)
        #expect(details[0]["userWebinarId"] as? Int == 0)
        #expect(details[0]["meetingId"] is NSNull)
        #expect(details[0]["startTime"] is NSNull)
        #expect(details[0]["endTime"] is NSNull)
        #expect(details[0]["iCalUId"] is NSNull)
    }

    /// The web sends no `webinarAccount` at all once the link is hand-entered — there is
    /// no stored account behind that meeting — so the key is omitted, not nulled.
    @Test func noWebinarAccountTravelsWithAHandEnteredLink() throws {
        let draft = onlineDraft(.teams)
        draft.teamsLink = "https://team.link"

        let object = try encodeToObject(.init(draft: draft))

        #expect(object["webinarAccount"] == nil)
        #expect(object.keys.contains("webinarAccount") == false)
        // Still an online Teams schedule, and the link still travels.
        #expect(object["isWebinar"] as? Bool == true)
        #expect(object["webinarType"] as? String == "TEAMS")
        #expect((object["teamsScheduleDetails"] as? [Any])?.count == 1)
    }

    /// Without a hand-entered link the account is the only thing identifying the meeting
    /// host, so it must keep going out. `ENC_ACCOUNT==` is not decryptable, which is the
    /// passthrough case — an account is never dropped from the body.
    @Test func theWebinarAccountStillTravelsForAGeneratedMeeting() throws {
        let teams = try encodeToObject(.init(draft: onlineDraft(.teams)))
        let zoom = try encodeToObject(.init(draft: onlineDraft(.zoom)))

        #expect(teams["webinarAccount"] as? String == "ENC_ACCOUNT==")
        #expect(zoom["webinarAccount"] as? String == "ENC_ACCOUNT==")
    }

    /// The credential endpoints return the host address AES-encrypted; the web posts it in
    /// the clear (`"webinarAccount": "sysadmin@enthralltech.com"`), so it is decrypted on
    /// the way into the body.
    @Test func theWebinarAccountIsSentDecrypted() throws {
        let encrypted = EncryptDecryptUtility.shared.newEncryptValueString(
            valueStr: "sysadmin@enthralltech.com"
        )
        #expect(encrypted != "sysadmin@enthralltech.com")   // guards the fixture itself

        let draft = onlineDraft(.zoom)
        draft.credential = [.init(id: 1043, teamsEmail: encrypted, username: nil, password: nil, isDefault: 0)]

        let object = try encodeToObject(.init(draft: draft))

        #expect(object["webinarAccount"] as? String == "sysadmin@enthralltech.com")
    }

    /// An address that arrives already in the clear is sent as-is, not blanked.
    @Test func anAlreadyPlainWebinarAccountSurvives() throws {
        let draft = onlineDraft(.zoom)
        draft.credential = [.init(id: 1043, teamsEmail: "sysadmin@enthralltech.com",
                                  username: nil, password: nil, isDefault: 0)]

        let object = try encodeToObject(.init(draft: draft))

        #expect(object["webinarAccount"] as? String == "sysadmin@enthralltech.com")
    }

    @Test func teamsStaticLinkIsNormalizedBeforeItIsSent() throws {
        let draft = onlineDraft(.teams)
        draft.teamsLink = "  <https://team.link>\n"

        let object = try encodeToObject(.init(draft: draft))
        let details = try #require(object["teamsScheduleDetails"] as? [[String: Any]])
        #expect(details[0]["joinUrl"] as? String == "https://team.link")
    }

    @Test func aLinkIsOnlySentForTeams() throws {
        // A link left over from a Teams selection must not follow the organiser to Zoom.
        let draft = onlineDraft(.zoom)
        draft.teamsLink = "https://team.link"

        let object = try encodeToObject(.init(draft: draft))
        #expect((object["teamsScheduleDetails"] as? [Any])?.isEmpty == true)
    }

    @Test func offlineScheduleCarriesNoLink() throws {
        let draft = offlineDraft()
        draft.teamsLink = "https://team.link"

        let object = try encodeToObject(.init(draft: draft))
        #expect((object["teamsScheduleDetails"] as? [Any])?.isEmpty == true)
    }

    @Test func aScheduleWithNoLinkKeepsTodaysBody() throws {
        // Regression pin on the key that used to be a hardcoded `[]`.
        let object = try encodeToObject(.init(draft: onlineDraft(.teams)))
        #expect((object["teamsScheduleDetails"] as? [Any])?.isEmpty == true)
    }

    @Test func onlyATypedLinkChangesTheCreateEndpoint() throws {
        #expect(CreateScheduleWizardDataModel.Payload(draft: onlineDraft(.zoom)).carriesClientMeetingDetails == false)
        #expect(CreateScheduleWizardDataModel.Payload(draft: onlineDraft(.teams)).carriesClientMeetingDetails == false)

        let withTeamsLink = onlineDraft(.teams)
        withTeamsLink.teamsLink = "https://team.link"
        #expect(CreateScheduleWizardDataModel.Payload(draft: withTeamsLink).carriesClientMeetingDetails)

        #expect(CreateScheduleWizardDataModel.CreateScheduleRequest().path.hasSuffix("/v1/ILTSchedule"))
        #expect(CreateScheduleWizardDataModel.PostWithMeetingRequest().path.hasSuffix("/ILTSchedule/PostWithMeeting"))
    }


    @Test func legacyTwelveHourPickerTimesAreConvertedTo24Hour() throws {
        // Compatibility for drafts made before the picker switched to canonical HH:mm.
        func pickerString(hour: Int, minute: Int) -> String {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let date = Calendar.current.date(from: components)!
            let f = DateFormatter()
            f.locale = .current
            f.dateFormat = "h:mm a"
            return f.string(from: date)
        }

        let draft = offlineDraft()
        draft.startTime = pickerString(hour: 16, minute: 47) // e.g. "4:47 PM"
        draft.endTime = pickerString(hour: 9, minute: 5)     // e.g. "9:05 AM"

        let object = try encodeToObject(.init(draft: draft))
        #expect(object["startTime"] as? String == "16:47")
        #expect(object["endTime"] as? String == "09:05")
    }

    @Test func apiTimesWithSecondsAreNormalizedToHoursAndMinutes() throws {
        let draft = offlineDraft()
        draft.startTime = "16:47:35"
        draft.endTime = "18:09:59"

        let object = try encodeToObject(.init(draft: draft))
        #expect(object["startTime"] as? String == "16:47")
        #expect(object["endTime"] as? String == "18:09")
    }

    @Test func responseEnvelopeDecodes() throws {
        let json = #"{"statusCode":200,"message":null,"responseObject":null,"description":"success"}"#
        let response = try JSONDecoder().decode(DM.CreateScheduleResponse.self, from: Data(json.utf8))
        #expect(response.statusCode == 200)
        #expect(response.message == nil)
        #expect(response.description == "success")
    }
}
