//
//  ScheduleDraft+Edit.swift
//  Create_Schedule_Kit
//
//  Hydrates the wizard draft from a fetched schedule (`GetScheduleDetailsByID`) so the
//  edit flow reuses the create wizard with every step prefilled. Pure mapping — no
//  network, no view-model state — so it is directly unit-testable.
//

import Foundation
import SwiftUIUtilities

extension ScheduleDraft {

    /// Prefill every draft field from the fetched schedule. `modules` (from
    /// `GetModulesILTByCourse`) and `timezones` resolve the full picker items; when a
    /// match is missing, a display-equivalent item is synthesized from the response so
    /// the locked fields still render.
    func apply(
        details: EditScheduleDataModel.ScheduleDetailsResponse,
        modules: [ScheduleBasicDetailsDataModel.ModuleItem],
        timezones: [ScheduleBasicDetailsDataModel.TimezoneItem]
    ) {
        // Step 1 — Basic details
        scheduleCode = details.scheduleCode ?? ""
        if let courseID = details.courseID {
            course = ScheduleBasicDetailsDataModel.Course(
                id: courseID,
                title: details.courseName ?? "",
                code: details.courseCode ?? ""
            )
        }
        if let moduleId = details.moduleId {
            module = modules.first { $0.id == moduleId } ?? ScheduleBasicDetailsDataModel.ModuleItem(
                id: moduleId,
                title: details.moduleName ?? "",
                type: details.courseType,
                courseFee: nil,
                currency: nil,
                category: details.categoryName,
                subCategory: details.subCategoryName,
                subSubCategory: details.subSubCategoryName
            )
        }
        deliveryMode = (details.isWebinar ?? false) ? .online : .offline
        webinarType = details.webinarType.flatMap { raw in
            WebinarType.allCases.first {
                $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame
                    || $0.displayTitle.caseInsensitiveCompare(raw) == .orderedSame
            }
        }
        if let account = details.webinarAccount, !account.isEmpty {
            credential = [
                ScheduleBasicDetailsDataModel.Credential(
                    id: nil, teamsEmail: account, username: nil, password: nil, isDefault: nil
                )
            ]
        }
        if let tz = details.timezone, !tz.isEmpty {
            // Dropdown selection matches by `id == value`, so a synthesized fallback
            // still selects correctly once the step loads the full timezone list.
            timezone = timezones.first { $0.value == tz }
                ?? ScheduleBasicDetailsDataModel.TimezoneItem(value: tz, code: "", offset: 0, isdst: false, name: tz)
        }
        startDate = Self.parseAPIDate(details.startDate)
        endDate = Self.parseAPIDate(details.endDate)
        registrationEndDate = Self.parseAPIDate(details.registrationEndDate)
        startTime = details.startTime.map(Self.displayTime)
        endTime = details.endTime.map(Self.displayTime)

        // Holidays — map the fetched rows, then normalize through the generator so ids
        // and row order always line up with the schedule range.
        let fetchedHolidays: [HolidayDay] = (details.holidayList ?? []).enumerated().compactMap { index, item in
            guard let date = Self.parseAPIDate(item.date) else { return nil }
            let isHoliday = item.isHoliday ?? false
            return HolidayDay(
                id: index,
                date: date,
                isHoliday: isHoliday,
                label: isHoliday ? (item.reason ?? "Holiday") : "Holiday"
            )
        }
        if let start = startDate, let end = endDate {
            holidays = HolidayDay.generate(start: start, end: end, existing: fetchedHolidays)
        } else {
            holidays = []
        }

        // Step 2 — Logistics
        if let academyID = details.academyAgencyID {
            academy = ScheduleLogisticsDataModel.Academy(
                id: academyID,
                title: details.academyAgencyName ?? "",
                type: nil
            )
        }
        if let placeID = details.placeID {
            trainingPlace = ScheduleLogisticsDataModel.TrainingPlace(
                id: placeID,
                placeCode: nil,
                cityname: details.city,
                placeName: details.placeName,
                accommodationCapacity: details.seatCapacity,
                postalAddress: details.postalAddress,
                contactNumber: details.contactNumber,
                contactPerson: details.contactPersonName
            )
        }
        trainerType = details.trainerType.flatMap { TrainerType(rawValue: $0.lowercased()) } ?? .internal
        trainers = (details.trainerList ?? []).compactMap { item in
            guard let trainerID = item.academyTrainerID else { return nil }
            // The draft stores the encrypted id (as trainer search returns it); the
            // payload builders decrypt it back — symmetric round-trip.
            return ScheduleLogisticsDataModel.Trainer(
                id: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "\(trainerID)"),
                name: item.academyTrainerName ?? "",
                emailId: item.trainerEmail ?? item.emailID,
                userId: nil,
                profilePicture: nil,
                mobileNumber: nil,
                userType: item.trainerType,
                nameUserId: item.nameUserId
            )
        }
        tags = (details.tagList ?? []).compactMap { item in
            guard let tagId = item.tagId else { return nil }
            return ScheduleLogisticsDataModel.Tag(id: tagId, tag: item.tag, tagCode: nil, isActive: nil)
        }
        coordinatorName = details.contactPersonName ?? ""
        contactNumber = details.contactNumber ?? ""

        // Step 3 — Feedback
        if let feedbackId = details.feedbackId, feedbackId > 0 {
            feedbackModule = ScheduleFeedbackDataModel.FeedbackModule(
                id: String(feedbackId),
                title: details.feedbackName ?? "",
                category: nil
            )
        }
    }

    // MARK: - Parsing helpers

    /// Parses API date strings — `"2026-08-04T00:00:00"` with a plain-day fallback.
    static func parseAPIDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    /// `"19:10"` → `"7:10 PM"` — the exact inverse of `Payload.apiTime`. The draft keeps
    /// times as 12-hour strings in `Locale.current` (what `TimePickerTextField` stores).
    /// Values that don't parse pass through unchanged (`apiTime` also passes `"HH:mm"`
    /// through, so submits stay correct either way).
    static func displayTime(_ raw: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "HH:mm"
        guard let date = input.date(from: raw) else { return raw }
        let output = DateFormatter()
        output.locale = .current
        output.dateFormat = "h:mm a"
        return output.string(from: date)
    }
}
