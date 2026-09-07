//
//  CreateScheduleWizardDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoint + DTOs for the final create-schedule submit (`ILTSchedule/PostWithMeeting`).
//  The request body uses explicit `null`s and exact (mixed-case) key names — see the manual
//  `encode(to:)` on `Payload`. Encrypted server fields (trainer email, webinar account) are
//  passed through untouched; the numeric trainer id is decrypted in-package.
//

import Foundation
import NetworkService
import SwiftUIUtilities

enum CreateScheduleWizardDataModel {

    // MARK: - Endpoint

    /// POST create schedule with webinar/meeting details.
    struct PostWithMeetingRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.postWithMeeting]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST create schedule — the plain route, used when the client already holds the
    /// meeting details (a typed Teams link or a generated provider meeting) rather than
    /// asking the server to mint one.
    struct CreateScheduleRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule].joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Response envelope

    /// `{"statusCode":200,"message":null,"responseObject":null,"description":"success"}`
    struct CreateScheduleResponse: Decodable {
        let statusCode: Int?
        let message: String?
        let description: String?

        /// The server's own explanation of a refused submit.
        ///
        /// This envelope carries it under `message` on some routes and `description` on
        /// others, so both are consulted — reading only `message` left a real reason
        /// ("training place is already booked") hidden behind a generic fallback.
        /// `"success"` is ignored: it is the description these routes send on the happy
        /// path and would read absurdly in a failure toast.
        var serverMessage: String? {
            for candidate in [message, description] {
                let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !trimmed.isEmpty, trimmed.caseInsensitiveCompare("success") != .orderedSame
                else { continue }
                return trimmed
            }
            return nil
        }
    }

    // MARK: - Nested DTOs

    struct TagDTO: Encodable {
        let tagId: Int
        let tag: String
    }

    struct TrainerDTO: Encodable {
        let academyTrainerID: Int
        let academyTrainerName: String
        let trainerType: String
        let nameUserId: String
        let emailID: String
        let trainerEmail: String
    }

    struct HolidayDTO: Encodable {
        let date: String
        let isHoliday: Bool
        let reason: String
    }

    /// One entry of `teamsScheduleDetails`, carrying a hand-entered Teams link. Every other
    /// field is the server's own scaffolding — the web client sends these zeros and nulls
    /// verbatim and the API expects the shape, so they are reproduced here rather than
    /// omitted.
    struct TeamsScheduleDetailDTO: Encodable {
        var id = 0
        var courseID = 0
        var scheduleID = 0
        var meetingId: String? = nil
        var startTime: String? = nil
        var endTime: String? = nil
        var iCalUId: String? = nil
        let joinUrl: String
        var userWebinarId = 0

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(courseID, forKey: .courseID)
            try c.encode(scheduleID, forKey: .scheduleID)
            try c.encode(meetingId, forKey: .meetingId)
            try c.encode(startTime, forKey: .startTime)
            try c.encode(endTime, forKey: .endTime)
            try c.encode(iCalUId, forKey: .iCalUId)
            try c.encode(joinUrl, forKey: .joinUrl)
            try c.encode(userWebinarId, forKey: .userWebinarId)
        }

        enum CodingKeys: String, CodingKey {
            case id, courseID, scheduleID, meetingId, startTime, endTime, iCalUId, joinUrl, userWebinarId
        }
    }

    // MARK: - Payload

    struct Payload: Encodable {
        let scheduleCode: String
        let moduleID: Int
        let moduleName: String
        let courseName: String
        let courseID: Int
        let tags: [TagDTO]
        let trainerType: String
        let academyAgencyId: Int?
        let academyAgencyName: String?
        let city: String?
        let seatCapacity: String
        let scheduleCapacity: String
        let postalAddress: String?
        let placeID: Int?
        let placeName: String?
        let placeType: String
        let startDate: String
        let endDate: String
        let startTime: String
        let endTime: String
        let registrationEndDate: String
        let trainers: [TrainerDTO]
        let holidays: [HolidayDTO]
        let isFeedback: Bool?
        let feedbackId: Int?
        let timezone: String
        let isWebinar: Bool
        let webinarType: String?
        let webinarAccount: String?
        /// Empty unless the organiser entered a Teams link by hand.
        let teamsScheduleDetails: [TeamsScheduleDetailDTO]

        enum CodingKeys: String, CodingKey {
            case id, scheduleCode, batchCode, batchName, batchId
            case moduleID, moduleName, courseName
            case Taglist
            case trainerType, academyAgencyId, academyAgencyName
            case academyTrainerId, academyTrainerName
            case AgencyTrainerName, trainerDescription
            case city, seatCapacity, scheduleCapacity, postalAddress
            case contactPersonName, contactNumber
            case placeID, placeName, placeType, emailId
            case startDate, endDate, startTime, endTime, registrationEndDate
            case isActive, courseID, eventLogo
            case TrainerList
            case cost, currency
            case holidayList
            case webinarType
            case teamsScheduleDetails
            case purpose, requestApproval
            case isFeedback, feedbackId
            case createdBy, createdDate, modifiedDate, modifiedBy
            case timezone, isWebinar, webinarAccount
        }

        /// True when this body already carries the meeting the schedule should use, which
        /// is what decides between `CreateScheduleRequest` and `PostWithMeetingRequest`.
        var carriesClientMeetingDetails: Bool { !teamsScheduleDetails.isEmpty }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(0, forKey: .id)
            try c.encode(scheduleCode, forKey: .scheduleCode)
            try c.encodeNil(forKey: .batchCode)
            try c.encodeNil(forKey: .batchName)
            try c.encodeNil(forKey: .batchId)
            try c.encode(moduleID, forKey: .moduleID)
            try c.encode(moduleName, forKey: .moduleName)
            try c.encode(courseName, forKey: .courseName)
            try c.encode(tags, forKey: .Taglist)
            try c.encode(trainerType, forKey: .trainerType)
            try c.encode(academyAgencyId, forKey: .academyAgencyId)
            try c.encode(academyAgencyName, forKey: .academyAgencyName)
            try c.encodeNil(forKey: .academyTrainerId)
            try c.encodeNil(forKey: .academyTrainerName)
            try c.encodeNil(forKey: .AgencyTrainerName)
            try c.encodeNil(forKey: .trainerDescription)
            try c.encode(city, forKey: .city)
            try c.encode(seatCapacity, forKey: .seatCapacity)
            try c.encode(scheduleCapacity, forKey: .scheduleCapacity)
            try c.encode(postalAddress, forKey: .postalAddress)
            try c.encodeNil(forKey: .contactPersonName)
            try c.encodeNil(forKey: .contactNumber)
            try c.encode(placeID, forKey: .placeID)
            try c.encode(placeName, forKey: .placeName)
            try c.encode(placeType, forKey: .placeType)
            try c.encodeNil(forKey: .emailId)
            try c.encode(startDate, forKey: .startDate)
            try c.encode(endDate, forKey: .endDate)
            try c.encode(startTime, forKey: .startTime)
            try c.encode(endTime, forKey: .endTime)
            try c.encode(registrationEndDate, forKey: .registrationEndDate)
            try c.encode(true, forKey: .isActive)
            try c.encode(courseID, forKey: .courseID)
            try c.encodeNil(forKey: .eventLogo)
            try c.encode(trainers, forKey: .TrainerList)
            try c.encode(0, forKey: .cost)
            try c.encode("", forKey: .currency)
            try c.encode(holidays, forKey: .holidayList)
            if isWebinar {
                try c.encode(webinarType, forKey: .webinarType)
            }
            // Encodes as `[]` whenever no link was typed, which is what this body has always sent.
            try c.encode(teamsScheduleDetails, forKey: .teamsScheduleDetails)
            try c.encode("Planned Training", forKey: .purpose)
            try c.encodeNil(forKey: .requestApproval)
            try c.encode(isFeedback, forKey: .isFeedback)
            try c.encode(feedbackId, forKey: .feedbackId)
            try c.encodeNil(forKey: .createdBy)
            try c.encodeNil(forKey: .createdDate)
            try c.encodeNil(forKey: .modifiedDate)
            try c.encodeNil(forKey: .modifiedBy)
            try c.encode(timezone, forKey: .timezone)
            try c.encode(isWebinar, forKey: .isWebinar)
            if isWebinar {
                try c.encode(webinarAccount, forKey: .webinarAccount)
            }
        }
    }
}

// MARK: - Draft → Payload mapping

extension CreateScheduleWizardDataModel.Payload {

    /// Builds the create-schedule request body from the collected wizard state.
    init(draft: ScheduleDraft) {
        typealias DM = CreateScheduleWizardDataModel
        let isWebinar = draft.deliveryMode == .online

        let trainers: [DM.TrainerDTO] = draft.trainers.map { trainer in
            let decryptedId = EncryptDecryptUtility.shared.newDecryptString(responseStr: trainer.id)
            return DM.TrainerDTO(
                academyTrainerID: Int(decryptedId) ?? 0,
                academyTrainerName: trainer.name,
                trainerType: draft.trainerType.apiValue,
                nameUserId: trainer.nameUserId ?? trainer.name,
                emailID: trainer.emailId ?? "",
                trainerEmail: trainer.emailId ?? ""
            )
        }

        // Always send a row per day in the range, normalized through the generator so the
        // markings line up with the current dates and the boundary days stay working days.
        let holidayRows: [HolidayDay] = {
            guard let start = draft.startDate, let end = draft.endDate else { return draft.holidays }
            return HolidayDay.generate(start: start, end: end, existing: draft.holidays)
        }()
        let holidays: [DM.HolidayDTO] = holidayRows.map { row in
            DM.HolidayDTO(
                date: Self.dayString(row.date),
                isHoliday: row.isHoliday,
                reason: row.isHoliday ? row.label : "Work Day"
            )
        }

        let feedbackId = draft.feedbackModule.flatMap { Int($0.id) }

        // A hand-entered link only ever exists for Teams while `ATPTLWCS` is on; every
        // other schedule keeps sending the empty array this body has always carried.
        let teamsScheduleDetails: [DM.TeamsScheduleDetailDTO] = {
            guard isWebinar, draft.webinarType == .teams,
                  let link = draft.teamsLink.map(WebinarLinkRules.normalizedLink),
                  !link.isEmpty
            else { return [] }
            return [DM.TeamsScheduleDetailDTO(joinUrl: link)]
        }()

        self.init(
            scheduleCode: draft.scheduleCode,
            moduleID: draft.module?.id ?? 0,
            moduleName: draft.module?.title ?? "",
            courseName: draft.course?.title ?? "",
            courseID: draft.course?.id ?? 0,
            tags: draft.tags.map { DM.TagDTO(tagId: $0.id, tag: $0.tag ?? "") },
            trainerType: draft.trainerType.apiValue,
            academyAgencyId: draft.academy?.id,
            academyAgencyName: draft.academy?.title,
            city: draft.trainingPlace?.cityname,
            seatCapacity: draft.trainingPlace?.accommodationCapacity ?? "",
            scheduleCapacity: draft.trainingPlace?.accommodationCapacity ?? "",
            postalAddress: draft.trainingPlace?.postalAddress,
            placeID: draft.trainingPlace?.id,
            placeName: draft.trainingPlace?.placeName,
            placeType: "Internal",
            startDate: draft.startDate.map(Self.isoDate) ?? "",
            endDate: draft.endDate.map(Self.isoDate) ?? "",
            startTime: draft.startTime.map(Self.apiTime) ?? "",
            endTime: draft.endTime.map(Self.apiTime) ?? "",
            registrationEndDate: draft.registrationEndDate.map(Self.isoDate) ?? "",
            trainers: trainers,
            holidays: holidays,
            isFeedback: draft.feedbackModule != nil ? true : nil,
            feedbackId: feedbackId,
            timezone: draft.timezone?.value ?? "",
            isWebinar: isWebinar,
            webinarType: isWebinar ? draft.webinarType?.rawValue : nil,
            webinarAccount: isWebinar ? draft.credential?.first?.teamsEmail : nil,
            teamsScheduleDetails: teamsScheduleDetails
        )
    }

    /// `2026-06-24T00:00:00.000Z` — the picked calendar day at UTC-midnight, matching the web payload.
    /// Shared with the attendance insert body, so the format lives on `Date`.
    static func isoDate(_ date: Date) -> String {
        date.isoDayStartUTCString
    }

    /// `2026-06-24` — used inside `holidayList`.
    static func dayString(_ date: Date) -> String {
        formatter(format: "yyyy-MM-dd").string(from: date)
    }

    /// Returns the API's canonical 24-hour `HH:mm` representation. API values with seconds
    /// and old 12-hour picker values are normalized as well, which keeps existing drafts safe.
    /// Unexpected values pass through unchanged rather than being silently erased.
    static func apiTime(_ raw: String) -> String {
        ScheduleDateRules.canonical24HourTime(raw) ?? raw
    }

    private static func formatter(format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = format
        return f
    }
}
