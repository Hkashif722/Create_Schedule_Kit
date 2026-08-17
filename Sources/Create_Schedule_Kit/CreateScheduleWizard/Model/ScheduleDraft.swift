//
//  ScheduleDraft.swift
//  Create_Schedule_Kit
//
//  Shared, mutable wizard state. Owned by the wizard coordinator and passed by
//  reference into each step's view model so selections persist across steps.
//

import Foundation

// MARK: - Cross-cutting enums

/// Whether the wizard creates a new schedule or edits an existing one.
enum WizardMode: Equatable {
    case create
    case edit(scheduleID: Int)

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    var scheduleID: Int? {
        if case .edit(let id) = self { return id }
        return nil
    }
}

enum DeliveryMode: String, CaseIterable {
    case online
    case offline

    var displayTitle: String {
        switch self {
        case .online:  return "Online"
        case .offline: return "Offline"
        }
    }
}

enum WebinarType: String, CaseIterable, Identifiable {
    case zoom
    case teams
    case googleMeet
    case gotoMeeting

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .zoom:        return "Zoom"
        case .teams:       return "Microsoft Teams"
        case .googleMeet:  return "Google Meet"
        case .gotoMeeting: return "GoTo Meeting"
        }
    }

    /// Whether this provider exposes a stored-credential API. GoTo Meeting does not.
    var hasCredentialAPI: Bool {
        switch self {
        case .zoom, .teams, .googleMeet: return true
        case .gotoMeeting:               return false
        }
    }
}

enum TrainerType: String, CaseIterable {
    case `internal`
    case external
    case consultant

    var displayTitle: String {
        switch self {
        case .internal:   return "Internal"
        case .external:   return "External"
        case .consultant: return "Consultant"
        }
    }

    /// Value sent to the trainer-search API (capitalised type).
    var apiValue: String { displayTitle }
}

// MARK: - Holiday model

struct HolidayDay: Identifiable, Equatable {
    let id: Int          // day index within the schedule range
    let date: Date
    var isHoliday: Bool
    var label: String    // "Holiday" / "Weekend" / custom name

    /// Generates one row per day in [start, end]. Weekends default to holidays
    /// labelled "Weekend"; weekdays default to working days labelled "Holiday".
    /// Any matching existing rows (same calendar day) are preserved.
    static func generate(start: Date, end: Date, existing: [HolidayDay] = []) -> [HolidayDay] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        var rows: [HolidayDay] = []
        var cursor = startDay
        var index = 0
        while cursor <= endDay {
            let weekday = calendar.component(.weekday, from: cursor) // 1 = Sunday, 7 = Saturday
            let isWeekend = (weekday == 1 || weekday == 7)

            if let match = existing.first(where: { calendar.isDate($0.date, inSameDayAs: cursor) }) {
                rows.append(HolidayDay(id: index, date: cursor, isHoliday: match.isHoliday, label: match.label))
            } else {
                rows.append(HolidayDay(id: index, date: cursor, isHoliday: isWeekend, label: isWeekend ? "Weekend" : "Holiday"))
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            index += 1
        }
        return rows
    }
}

// MARK: - Schedule Draft

final class ScheduleDraft {

    // Step 1 — Basic details
    var scheduleCode: String = ""
    var course: ScheduleBasicDetailsDataModel.Course?
    var module: ScheduleBasicDetailsDataModel.ModuleItem?
    var deliveryMode: DeliveryMode = .online
    var webinarType: WebinarType?
    var credential: ScheduleBasicDetailsDataModel.Credential?
    var timezone: ScheduleBasicDetailsDataModel.TimezoneItem?
    var startDate: Date?
    var endDate: Date?
    var registrationEndDate: Date?
    var startTime: String?
    var endTime: String?
    var holidays: [HolidayDay] = []

    // Step 2 — Logistics
    var academy: ScheduleLogisticsDataModel.Academy?
    var trainingPlace: ScheduleLogisticsDataModel.TrainingPlace?
    var trainerType: TrainerType = .internal
    var trainers: [ScheduleLogisticsDataModel.Trainer] = []
    var tags: [ScheduleLogisticsDataModel.Tag] = []
    var coordinatorName: String = ""
    var contactNumber: String = ""

    // Step 3 — Feedback (optional, single module per schedule)
    var feedbackModule: ScheduleFeedbackDataModel.FeedbackModule? = nil

    init() {}
}
