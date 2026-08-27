//
//  ScheduleListDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the Scheduler landing screen (list of schedules).
//
//   • ILTSchedule/GetScheduleData            → [Schedule]  (paginated list)
//   • ILTSchedule/count/{s}/{st}/{showAll}   → Int         (total count, parallel)
//   • TrainingNomination/GetNominateUserCount → Int        (participants per schedule)
//   • ConfigurableParameters/GetValue/{key}  → ConfigValueResponse
//   • i/ILTBatch/IsBatchwiseNominationEnabled → reused from NominateUsersDataModel
//

import Foundation
import NetworkService
import SwiftUIUtilities

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
        /// `"true"` mirrors `ListPayload.showAllData` — with `"false"` the server withholds
        /// past schedules, so the count would disagree with the list on the Completed tab.
        var showAllData: String = "true"
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule, APIConst.count,
             search, searchText, showAllData].joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// POST — nominated participant count for one schedule. Returns a bare `Int`.
    struct GetNominateUserCountRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingNomination,
             APIConst.getNominateUserCount].joined(separator: "/")
        }
        var method: HTTPMethod { .post }
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

    /// Body for `GetNominateUserCount`. The API expects the nullable filter keys to be
    /// present as JSON `null`, so these values are encoded explicitly rather than omitted.
    struct NominateUserCountPayload: Encodable {
        let scheduleID: Int
        let courseId: Int
        let moduleId: Int
        let page: Int
        let pageSize: Int
        let search: String
        let searchText: String?
        let search1: String?
        let searchText1: String?
        let type: String?

        enum CodingKeys: String, CodingKey {
            case scheduleID, courseId, moduleId, page, pageSize
            case search, searchText, search1, searchText1
            case type = "Type"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(scheduleID, forKey: .scheduleID)
            try container.encode(courseId, forKey: .courseId)
            try container.encode(moduleId, forKey: .moduleId)
            try container.encode(page, forKey: .page)
            try container.encode(pageSize, forKey: .pageSize)
            try container.encode(search, forKey: .search)
            try container.encodeOptional(searchText, forKey: .searchText)
            try container.encodeOptional(search1, forKey: .search1)
            try container.encodeOptional(searchText1, forKey: .searchText1)
            try container.encodeOptional(type, forKey: .type)
        }
    }

    // MARK: - Search

    /// Column the search box filters on — the package mirror of the web client's "Filter"
    /// dropdown. The value goes out as `Search` in `ListPayload`, paired with `searchText`:
    /// `{"Page":1,"PageSize":10,"Search":"moduleName","searchText":"aa"}`. Sending the text
    /// without a column is ignored by the server, so the two always travel together.
    ///
    /// Only `moduleName` is confirmed against a captured request; the rest follow the same
    /// field-name convention as the `Schedule` DTO. If the server rejects one, the fix is the
    /// `apiValue` below and nothing else.
    enum FilterColumn: String, CaseIterable, Identifiable, DropDownMenuProtocolPkg {
        case moduleName
        case scheduleCode
        case courseName
        case academyName
        case scheduleType
        case createdBy

        var id: String { rawValue }

        /// Label shown in the dropdown — matches the web wording.
        var title: String {
            switch self {
            case .moduleName:   return "Module Name"
            case .scheduleCode: return "Schedule Code"
            case .courseName:   return "Course Name"
            case .academyName:  return "Academy Name"
            case .scheduleType: return "Schedule Type"
            case .createdBy:    return "Created By"
            }
        }

        var description: String { title }

        /// Value sent as `Search`.
        var apiValue: String {
            switch self {
            case .academyName: return "academyAgencyName"
            default:           return rawValue
            }
        }
    }

    // MARK: - Response / domain models

    struct ConfigValueResponse: Decodable {
        let value: String?

        /// Config flags come back as `{"value":"Yes"}` / `{"value":"No"}`. Anything that is
        /// not an explicit "Yes" — including a missing value — reads as off.
        var isYes: Bool {
            (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "yes"
        }
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

private extension KeyedEncodingContainer {
    mutating func encodeOptional<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

// MARK: - Display helpers

extension ScheduleListDataModel.Schedule {

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
        guard let date = ScheduleDraft.parseAPIDate(startDate) else { return "" }
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
        guard let date = ScheduleDraft.parseAPIDate(raw) else { return "" }
        return date.formatted(using: "MMM dd, yyyy")
    }

    /// "Pune · Enthralltech"
    var locationText: String {
        [city, academyAgencyName ?? placeName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Parsed end date for the Upcoming/Completed tab filter. Uses the tolerant parser for the
    /// same reason `registrationEndDateValue` does — the API sometimes sends a date-only value
    /// (`"2026-08-14"`), and an unparseable end date here forces the row into Upcoming, which is
    /// what kept finished schedules out of the Completed tab.
    var endDateValue: Date? {
        ScheduleDraft.parseAPIDate(endDate)
    }

    /// Parsed registration end date, used to gate cancellation. An unparseable value here closes
    /// the window and would block cancelling outright.
    var registrationEndDateValue: Date? {
        ScheduleDraft.parseAPIDate(registrationEndDate)
    }

    /// Whether registration is still open — a schedule cannot be cancelled after its registration
    /// end date. Day-granular on both sides, so the registration-end day itself still counts as
    /// open. A missing or unparseable date reads as closed.
    var isWithinRegistrationWindow: Bool {
        guard let regEnd = registrationEndDateValue else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: Date()) <= calendar.startOfDay(for: regEnd)
    }

    /// A cancelled schedule is read-only: it can be viewed but not edited, attended or cancelled
    /// again. The server reports this through `scheduleType` ("Scheduled" vs. a cancelled variant),
    /// so the match is a case-insensitive substring rather than an equality check — the exact
    /// spelling ("Cancelled" / "Canceled" / "Cancellation") differs across endpoints.
    var isCancelled: Bool {
        guard let type = scheduleType else { return false }
        return type.lowercased().contains("cancel")
    }

    var participants: Int { participantsCount ?? 0 }

    // MARK: - Detail-screen display

    /// Big title on the detail header (course name, falling back to module / code).
    var detailTitle: String { courseName ?? moduleName ?? scheduleCode ?? "Schedule" }

    /// Day-granular Upcoming/Completed split from the end date — the single source of truth for
    /// both the list tabs (`ScheduleListViewModel.displayItems`) and the detail header pill. A
    /// schedule ending today is still upcoming; it moves to Completed tomorrow. An unparseable
    /// end date reads as upcoming.
    var isUpcoming: Bool {
        guard let end = endDateValue else { return true }
        let calendar = Calendar.current
        return calendar.startOfDay(for: end) >= calendar.startOfDay(for: Date())
    }
    var statusText: String { isUpcoming ? "Upcoming" : "Completed" }

    /// "Offline · Bangalore" / "Online · Bangalore"
    var deliveryText: String {
        Self.deliveryText(isWebinar: isWebinar, webinarType: webinarType, city: city)
    }

    /// The list endpoint omits the webinar fields — the detail screen resolves them from `GetScheduleDetailsByID`.
    static func deliveryText(isWebinar: Bool?, webinarType: String?, city: String?) -> String {
        let mode = (isWebinar == true || (webinarType?.isEmpty == false)) ? "Online" : "Offline"
        guard let city, !city.isEmpty else { return mode }
        return "\(mode) · \(city)"
    }

    /// "24 Jun 2026"
    var regEndText: String {
        guard let date = registrationEndDateValue else { return "" }
        return date.formatted(using: "dd MMM yyyy")
    }

    var seatCapacityText: String {
        Self.seatCapacityText(seatCapacity: seatCapacity, scheduleCapacity: scheduleCapacity)
    }

    var coordinator: String {
        Self.coordinatorText(contactPersonName: contactPersonName)
    }

    static func seatCapacityText(seatCapacity: String?, scheduleCapacity: Int?) -> String {
        if let seat = seatCapacity, !seat.isEmpty { return seat }
        if let cap = scheduleCapacity, cap > 0 { return "\(cap)" }
        return "-"
    }

    static func coordinatorText(contactPersonName: String?) -> String {
        (contactPersonName?.isEmpty == false) ? contactPersonName! : "-"
    }

    var trainerName: String {
        (academyTrainerName?.isEmpty == false) ? academyTrainerName! : "-"
    }

    private static func shortTime(_ raw: String?) -> String {
        guard let raw, let date = apiTimeFormatter.date(from: raw) else { return raw ?? "" }
        return date.formatted(using: "HH:mm")
    }
}
