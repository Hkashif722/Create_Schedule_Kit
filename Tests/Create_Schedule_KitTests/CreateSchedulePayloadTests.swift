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
        #expect(object["scheduleCapacity"] as? String == "100")
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

    // MARK: - Teams static link

    private func onlineDraft(_ type: WebinarType) -> ScheduleDraft {
        let draft = offlineDraft()
        draft.deliveryMode = .online
        draft.webinarType = type
        draft.credential = [.init(id: 1043, teamsEmail: "ENC_ACCOUNT==", username: nil, password: nil, isDefault: 0)]
        return draft
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
