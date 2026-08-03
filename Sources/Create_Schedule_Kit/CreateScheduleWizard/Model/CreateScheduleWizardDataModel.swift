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

    // MARK: - Response envelope

    /// `{"statusCode":200,"message":null,"responseObject":null,"description":"success"}`
    struct CreateScheduleResponse: Decodable {
        let statusCode: Int?
        let message: String?
        let description: String?
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
            try c.encode([String](), forKey: .teamsScheduleDetails)
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

        // Always send a row per day in the range. Use marked holidays if present, else regenerate.
        let holidayRows: [HolidayDay] = {
            if !draft.holidays.isEmpty { return draft.holidays }
            guard let start = draft.startDate, let end = draft.endDate else { return [] }
            return HolidayDay.generate(start: start, end: end)
        }()
        let holidays: [DM.HolidayDTO] = holidayRows.map { row in
            DM.HolidayDTO(
                date: Self.dayString(row.date),
                isHoliday: row.isHoliday,
                reason: row.isHoliday ? row.label : "Work Day"
            )
        }

        let feedbackId = draft.feedbackModule.flatMap { Int($0.id) }

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
            webinarAccount: isWebinar ? draft.credential?.teamsEmail : nil
        )
    }

    /// `2026-06-24T00:00:00.000Z` — the picked calendar day at UTC-midnight, matching the web payload.
    static func isoDate(_ date: Date) -> String {
        formatter(format: "yyyy-MM-dd'T'00:00:00.000'Z'").string(from: date)
    }

    /// `2026-06-24` — used inside `holidayList`.
    static func dayString(_ date: Date) -> String {
        formatter(format: "yyyy-MM-dd").string(from: date)
    }

    /// `"4:47 PM"` → `"16:47"`. The server expects a 24-hour `TimeSpan`, but `TimePickerTextField`
    /// stores the picked time as a 12-hour `"h:mm a"` string (in `Locale.current`). Parse with that
    /// same format/locale, then emit `"HH:mm"` with a fixed locale so the result is locale-independent.
    /// Passes the value through unchanged if it isn't 12-hour (already `"HH:mm"` or unparsable).
    static func apiTime(_ raw: String) -> String {
        let input = DateFormatter()
        input.locale = .current
        input.dateFormat = "h:mm a"
        guard let date = input.date(from: raw) else { return raw }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "HH:mm"
        return output.string(from: date)
    }

    private static func formatter(format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = format
        return f
    }
}
