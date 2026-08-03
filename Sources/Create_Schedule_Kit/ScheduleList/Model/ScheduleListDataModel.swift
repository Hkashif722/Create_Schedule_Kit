//
//  ScheduleListDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the Scheduler landing screen (list of schedules).
//
//   • ILTSchedule/GetScheduleData            → [Schedule]  (paginated list)
//   • ILTSchedule/count/{s}/{st}/{showAll}   → Int         (total count, parallel)
//   • ConfigurableParameters/GetValue/{key}  → ConfigValueResponse
//   • i/ILTBatch/IsBatchwiseNominationEnabled → reused from NominateUsersDataModel
//

import Foundation
import NetworkService

enum ScheduleListDataModel {

    // MARK: - Endpoints

    /// POST — paginated schedule list.
    struct GetScheduleDataRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.getScheduleData]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// GET — total schedule count. Path params mirror the list filters.
    struct ScheduleCountRequest: EndpointModel {
        var search: String = "null"
        var searchText: String = "null"
        var showAllData: String = "false"
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.count,
             search, searchText, showAllData].joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// GET — a single configurable parameter value.
    struct GetConfigValueRequest: EndpointModel {
        let key: String
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.configurableParameters, APIConst.getValue, key]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    // MARK: - Payload

    struct ListPayload: Encodable {
        let page: Int
        let pageSize: Int
        let search: String?
        let searchText: String?
        let showAllData: String

        enum CodingKeys: String, CodingKey {
            case page = "Page"
            case pageSize = "PageSize"
            case search = "Search"
            case searchText
            case showAllData
        }
    }

    // MARK: - Response / domain models

    struct ConfigValueResponse: Decodable {
        let value: String?
    }

    /// A schedule row. Only the fields shown on the card are mapped (plus `id`).
    /// `participantsCount` is optional — the API will start returning it later.
    struct Schedule: Decodable, Identifiable, Equatable {
        let id: Int
        let scheduleCode: String?
        let moduleName: String?
        let courseName: String?
        let startDate: String?
        let endDate: String?
        let startTime: String?
        let endTime: String?
        let city: String?
        let placeName: String?
        let academyAgencyName: String?
        let participantsCount: Int?

        // Detail-screen fields (all optional; present in the GetScheduleData response).
        let moduleId: Int?
        let courseID: Int?
        let courseCode: String?
        let registrationEndDate: String?
        let seatCapacity: String?
        let scheduleCapacity: Int?
        let contactPersonName: String?
        let trainerType: String?
        let academyTrainerName: String?
        let trainerDescription: String?
        let scheduleType: String?
        let purpose: String?
        let timezone: String?
        let isWebinar: Bool?
        let webinarType: String?
    }
}

// MARK: - Display helpers

extension ScheduleListDataModel.Schedule {

    private static let apiDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let apiTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Title shown on the card (module name, falling back to course name / code).
    var title: String {
        moduleName ?? courseName ?? scheduleCode ?? "Schedule"
    }

    /// "27 Jun 2026"
    var dateText: String {
        guard let raw = startDate, let date = Self.apiDateFormatter.date(from: raw) else { return "" }
        return date.formatted(using: "dd MMM yyyy")
    }

    /// "13:30 – 18:30"
    var timeRangeText: String {
        let start = Self.shortTime(startTime)
        let end = Self.shortTime(endTime)
        guard !start.isEmpty || !end.isEmpty else { return "" }
        return "\(start) – \(end)"
    }

    /// "Jul 02, 2026 – Jul 02, 2026" (falls back to a single date, else empty).
    var dateRangeText: String {
        let start = Self.mediumDate(startDate)
        let end = Self.mediumDate(endDate)
        if start.isEmpty { return end }
        if end.isEmpty || end == start { return start }
        return "\(start) – \(end)"
    }

    private static func mediumDate(_ raw: String?) -> String {
        guard let raw, let date = apiDateFormatter.date(from: raw) else { return "" }
        return date.formatted(using: "MMM dd, yyyy")
    }

    /// "Pune · Enthralltech"
    var locationText: String {
        [city, academyAgencyName ?? placeName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Parsed end date for the Upcoming/Completed tab filter.
    var endDateValue: Date? {
        guard let raw = endDate else { return nil }
        return Self.apiDateFormatter.date(from: raw)
    }

    var participants: Int { participantsCount ?? 0 }

    // MARK: - Detail-screen display

    /// Big title on the detail header (course name, falling back to module / code).
    var detailTitle: String { courseName ?? moduleName ?? scheduleCode ?? "Schedule" }

    /// Upcoming vs completed, from the end date.
    var isUpcoming: Bool {
        guard let end = endDateValue else { return true }
        return end >= Calendar.current.startOfDay(for: Date())
    }
    var statusText: String { isUpcoming ? "Upcoming" : "Completed" }

    /// "Offline · Bangalore" / "Online · Bangalore"
    var deliveryText: String {
        let mode = (isWebinar == true || (webinarType?.isEmpty == false)) ? "Online" : "Offline"
        guard let city, !city.isEmpty else { return mode }
        return "\(mode) · \(city)"
    }

    /// "24 Jun 2026"
    var regEndText: String {
        guard let raw = registrationEndDate, let date = Self.apiDateFormatter.date(from: raw) else { return "" }
        return date.formatted(using: "dd MMM yyyy")
    }

    var seatCapacityText: String {
        if let seat = seatCapacity, !seat.isEmpty { return seat }
        if let cap = scheduleCapacity, cap > 0 { return "\(cap)" }
        return "-"
    }

    var coordinator: String {
        (contactPersonName?.isEmpty == false) ? contactPersonName! : "-"
    }

    var purposeText: String {
        if let p = purpose, !p.isEmpty { return p }
        if let t = scheduleType, !t.isEmpty { return t }
        return "-"
    }

    var trainerName: String {
        (academyTrainerName?.isEmpty == false) ? academyTrainerName! : "-"
    }

    private static func shortTime(_ raw: String?) -> String {
        guard let raw, let date = apiTimeFormatter.date(from: raw) else { return raw ?? "" }
        return date.formatted(using: "HH:mm")
    }
}
