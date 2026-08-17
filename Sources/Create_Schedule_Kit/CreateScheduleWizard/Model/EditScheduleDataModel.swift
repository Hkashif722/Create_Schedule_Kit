//
//  EditScheduleDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the edit-schedule flow. The full schedule is fetched via
//  `ILTSchedule/GetScheduleDetailsByID` and kept as the *base* of the update payload:
//  `UpdateILTScheduleWithMeeting` expects the fetched object echoed back with the
//  edited fields overlaid (plus duplicated legacy keys — see `UpdatePayload`).
//  Fields whose shape the package does not model decode as `JSONValue` and are
//  echoed back verbatim. Encrypted server fields (trainer email) stay opaque.
//

import Foundation
import NetworkService
import SwiftUIUtilities

enum EditScheduleDataModel {

    // MARK: - Endpoints

    /// POST full schedule details by id.
    struct GetScheduleDetailsByIDRequest: EndpointModel {
        struct Payload: Encodable {
            let scheduleId: Int
        }

        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.getScheduleDetailsByID]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST update schedule (with webinar/meeting details). Response envelope is the
    /// same as create — reuse `CreateScheduleWizardDataModel.CreateScheduleResponse`.
    struct UpdateWithMeetingRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.updateILTScheduleWithMeeting]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Nested DTOs

    struct TrainerItem: Codable {
        let academyTrainerID: Int?
        let academyTrainerName: String?
        let trainerType: String?
        let emailID: String?
        let trainerEmail: String?   // encrypted opaque — pass through, never decode
        let nameUserId: String?
    }

    struct HolidayItem: Codable {
        let date: String?
        let isHoliday: Bool?
        let reason: String?
    }

    struct TagItem: Codable {
        let tagId: Int?
        let tag: String?
    }

    // MARK: - Details response

    /// Full schedule as returned by `GetScheduleDetailsByID`. Everything is optional
    /// except `id`; unmodelled shapes decode as `JSONValue` for verbatim echo-back.
    struct ScheduleDetailsResponse: Decodable {
        let id: Int
        let scheduleCode: String?
        let moduleId: Int?
        let batchId: Int?
        let startDate: String?
        let endDate: String?
        let startTime: String?
        let endTime: String?
        let startTimeString: String?
        let endTimeString: String?
        let registrationEndDate: String?
        let isActive: Bool?
        let isDeleted: Bool?
        let placeID: Int?
        let trainerType: String?
        let placeName: String?
        let moduleName: String?
        let courseName: String?
        let categoryName: String?
        let subCategoryName: String?
        let subSubCategoryName: String?
        let courseCode: String?
        let courseType: String?
        let academyAgencyID: Int?
        let academyAgencyName: String?
        let academyTrainerID: Int?
        let trainerList: [TrainerItem]?
        let holidayList: [HolidayItem]?
        let topicList: JSONValue?
        let agencyTrainerName: String?
        let academyTrainerName: String?
        let trainerDescription: String?
        let scheduleType: String?
        let reasonForCancellation: String?
        let city: String?
        let seatCapacity: String?
        let contactNumber: String?
        let postalAddress: String?
        let contactPersonName: String?
        let placeType: String?
        let courseID: Int?
        let status: Bool?
        let eventLogo: String?
        let cost: Double?
        let currency: String?
        let webinarType: String?
        let zoomCode: String?
        let batchCode: String?
        let batchName: String?
        let userName: String?
        let userCreated: JSONValue?
        let trainerName: String?
        let teamsScheduleDetails: JSONValue?
        let zoomScheduleDetails: JSONValue?
        let googleMeetDetails: JSONValue?
        let purpose: String?
        let scheduleCapacity: Int?
        let feedbackId: Int?
        let feedbackName: String?
        let createdDate: String?
        let modifiedDate: String?
        let createdBy: JSONValue?
        let modifiedBy: JSONValue?
        let timezone: String?
        let isWebinar: Bool?
        let webinarAccount: String?
        let tagList: [TagItem]?
        let record: Bool?
        let autoStartRecording: Bool?
        let allowStartStopRecording: Bool?
        let requestApproval: Bool?
    }

    // MARK: - Update payload

    /// Echo-back body for `UpdateILTScheduleWithMeeting`: the fetched schedule (`base`)
    /// re-encoded verbatim, with the wizard-edited fields overlaid from `draft`.
    /// Identity fields (course/module/delivery/webinar) are locked in the UI, so they
    /// always echo the base. The API also expects duplicated legacy keys:
    /// `moduleId`+`moduleID`, `trainerList`+`TrainerList`, `tagList`+`Taglist`,
    /// `agencyTrainerName`+`AgencyTrainerName`.
    struct UpdatePayload: Encodable {
        let base: ScheduleDetailsResponse
        let draft: ScheduleDraft

        enum CodingKeys: String, CodingKey {
            case id, scheduleCode, moduleId, moduleID, batchId
            case startDate, endDate, startTime, endTime, startTimeString, endTimeString
            case registrationEndDate, isActive, isDeleted, placeID, trainerType, placeName
            case moduleName, courseName, categoryName, subCategoryName, subSubCategoryName
            case courseCode, courseType, academyAgencyID, academyAgencyName, academyTrainerID
            case trainerList, TrainerList, holidayList, topicList
            case agencyTrainerName, AgencyTrainerName, academyTrainerName, trainerDescription
            case scheduleType, reasonForCancellation, city, seatCapacity, contactNumber
            case postalAddress, contactPersonName, placeType, courseID, status, eventLogo
            case cost, currency, webinarType, zoomCode, batchCode, batchName, userName
            case userCreated, trainerName, teamsScheduleDetails, zoomScheduleDetails, googleMeetDetails
            case purpose, scheduleCapacity, feedbackId, feedbackName, isFeedback
            case createdDate, modifiedDate, createdBy, modifiedBy
            case timezone, isWebinar, webinarAccount
            case tagList, Taglist
            case record, autoStartRecording, allowStartStopRecording, requestApproval
        }

        func encode(to encoder: Encoder) throws {
            typealias CreatePayload = CreateScheduleWizardDataModel.Payload
            var c = encoder.container(keyedBy: CodingKeys.self)

            // Identity + locked fields — echoed from the fetched schedule.
            try c.encode(base.id, forKey: .id)
            try c.encode(draft.scheduleCode.isEmpty ? base.scheduleCode : draft.scheduleCode, forKey: .scheduleCode)
            let moduleID = draft.module?.id ?? base.moduleId
            try c.encode(moduleID, forKey: .moduleId)
            try c.encode(moduleID, forKey: .moduleID)
            try c.encode(base.moduleName, forKey: .moduleName)
            try c.encode(base.courseID, forKey: .courseID)
            try c.encode(base.courseName, forKey: .courseName)
            try c.encode(base.courseCode, forKey: .courseCode)
            try c.encode(base.courseType, forKey: .courseType)
            try c.encode(base.categoryName, forKey: .categoryName)
            try c.encode(base.subCategoryName, forKey: .subCategoryName)
            try c.encode(base.subSubCategoryName, forKey: .subSubCategoryName)
            try c.encode(base.isWebinar ?? (draft.deliveryMode == .online), forKey: .isWebinar)
            try c.encode(base.webinarType, forKey: .webinarType)
            try c.encode(base.webinarAccount, forKey: .webinarAccount)
            try c.encode(base.zoomCode, forKey: .zoomCode)

            // Dates & times — draft values in the API formats, base as fallback.
            try c.encode(draft.startDate.map(CreatePayload.isoDate) ?? base.startDate, forKey: .startDate)
            try c.encode(draft.endDate.map(CreatePayload.isoDate) ?? base.endDate, forKey: .endDate)
            try c.encode(draft.registrationEndDate.map(CreatePayload.isoDate) ?? base.registrationEndDate, forKey: .registrationEndDate)
            try c.encode(draft.startTime.map(CreatePayload.apiTime) ?? base.startTime, forKey: .startTime)
            try c.encode(draft.endTime.map(CreatePayload.apiTime) ?? base.endTime, forKey: .endTime)
            try c.encode(base.startTimeString, forKey: .startTimeString)
            try c.encode(base.endTimeString, forKey: .endTimeString)
            try c.encode(draft.timezone?.value ?? base.timezone, forKey: .timezone)

            // Venue.
            try c.encode(draft.academy?.id ?? base.academyAgencyID, forKey: .academyAgencyID)
            try c.encode(draft.academy?.title ?? base.academyAgencyName, forKey: .academyAgencyName)
            let place = draft.trainingPlace
            try c.encode(place?.id ?? base.placeID, forKey: .placeID)
            try c.encode(place?.placeName ?? base.placeName, forKey: .placeName)
            try c.encode(place?.cityname ?? base.city, forKey: .city)
            let seatCapacity = place?.accommodationCapacity ?? base.seatCapacity
            try c.encode(seatCapacity, forKey: .seatCapacity)
            try c.encode(seatCapacity.flatMap(Int.init) ?? base.scheduleCapacity, forKey: .scheduleCapacity)
            try c.encode(place?.postalAddress ?? base.postalAddress, forKey: .postalAddress)
            try c.encode(base.placeType, forKey: .placeType)

            // Trainers.
            let trainers = trainerItems()
            try c.encode(trainers, forKey: .trainerList)
            try c.encode(trainers, forKey: .TrainerList)
            try c.encode(draft.trainerType.apiValue, forKey: .trainerType)
            try c.encode(base.academyTrainerID, forKey: .academyTrainerID)
            try c.encode(base.academyTrainerName, forKey: .academyTrainerName)
            try c.encode(base.agencyTrainerName, forKey: .agencyTrainerName)
            try c.encode(base.agencyTrainerName, forKey: .AgencyTrainerName)
            try c.encode(base.trainerDescription, forKey: .trainerDescription)
            try c.encode(base.trainerName, forKey: .trainerName)

            // Tags.
            let tags = draft.tags.map { TagItem(tagId: $0.id, tag: $0.tag ?? "") }
            try c.encode(tags, forKey: .tagList)
            try c.encode(tags, forKey: .Taglist)

            // Holidays — one row per day in the CURRENT range. Editing can change the
            // dates after hydration, so always normalize through the generator: rows
            // inside the range keep their markings, stale out-of-range rows drop out.
            let holidayRows: [HolidayDay] = {
                guard let start = draft.startDate, let end = draft.endDate else { return draft.holidays }
                return HolidayDay.generate(start: start, end: end, existing: draft.holidays)
            }()
            let holidays = holidayRows.map { row in
                HolidayItem(
                    date: CreatePayload.dayString(row.date),
                    isHoliday: row.isHoliday,
                    reason: row.isHoliday ? row.label : "Work Day"
                )
            }
            try c.encode(holidays, forKey: .holidayList)
            try c.encode(base.topicList ?? .null, forKey: .topicList)

            // Coordinator — real values in edit (create sends null here).
            try c.encode(draft.coordinatorName.isEmpty ? base.contactPersonName : draft.coordinatorName, forKey: .contactPersonName)
            try c.encode(draft.contactNumber.isEmpty ? base.contactNumber : draft.contactNumber, forKey: .contactNumber)

            // Feedback.
            try c.encode(draft.feedbackModule != nil, forKey: .isFeedback)
            try c.encode(draft.feedbackModule.flatMap { Int($0.id) }, forKey: .feedbackId)
            try c.encode(draft.feedbackModule?.title, forKey: .feedbackName)

            // Pass-through metadata.
            try c.encode(base.batchId, forKey: .batchId)
            try c.encode(base.batchCode, forKey: .batchCode)
            try c.encode(base.batchName, forKey: .batchName)
            try c.encode(base.isActive ?? true, forKey: .isActive)
            try c.encode(base.isDeleted ?? false, forKey: .isDeleted)
            try c.encode(base.status, forKey: .status)
            try c.encode(base.scheduleType, forKey: .scheduleType)
            try c.encode(base.reasonForCancellation, forKey: .reasonForCancellation)
            try c.encode(base.eventLogo, forKey: .eventLogo)
            try c.encode(base.cost ?? 0, forKey: .cost)
            try c.encode(base.currency ?? "", forKey: .currency)
            try c.encode(base.userName, forKey: .userName)
            try c.encode(base.userCreated ?? .null, forKey: .userCreated)
            try c.encode(base.teamsScheduleDetails ?? .null, forKey: .teamsScheduleDetails)
            try c.encode(base.zoomScheduleDetails ?? .null, forKey: .zoomScheduleDetails)
            try c.encode(base.googleMeetDetails ?? .null, forKey: .googleMeetDetails)
            try c.encode(base.purpose, forKey: .purpose)
            try c.encode(base.createdDate, forKey: .createdDate)
            try c.encode(base.modifiedDate, forKey: .modifiedDate)
            try c.encode(base.createdBy ?? .null, forKey: .createdBy)
            try c.encode(base.modifiedBy ?? .null, forKey: .modifiedBy)
            try c.encode(base.record ?? false, forKey: .record)
            try c.encode(base.autoStartRecording ?? false, forKey: .autoStartRecording)
            try c.encode(base.allowStartStopRecording ?? false, forKey: .allowStartStopRecording)
            try c.encode(base.requestApproval, forKey: .requestApproval)
        }

        /// Draft trainers mapped for the update body. Trainers that already exist on the
        /// fetched schedule are echoed verbatim (preserving the opaque encrypted
        /// `trainerEmail`); newly-added trainers are built from the search result the
        /// same way the create payload does.
        private func trainerItems() -> [TrainerItem] {
            let baseByID = Dictionary(
                (base.trainerList ?? []).compactMap { item in
                    item.academyTrainerID.map { ($0, item) }
                },
                uniquingKeysWith: { first, _ in first }
            )
            return draft.trainers.map { trainer in
                let decryptedId = EncryptDecryptUtility.shared.newDecryptString(responseStr: trainer.id)
                let trainerID = Int(decryptedId) ?? 0
                if let existing = baseByID[trainerID] { return existing }
                return TrainerItem(
                    academyTrainerID: trainerID,
                    academyTrainerName: trainer.name,
                    trainerType: draft.trainerType.apiValue,
                    emailID: trainer.emailId,
                    trainerEmail: trainer.emailId,
                    nameUserId: trainer.nameUserId ?? trainer.name
                )
            }
        }
    }
}
