//
//  ScheduleTabBucketingTests.swift
//  Create_Schedule_KitTests
//
//  Pins the Upcoming/Ongoing/Completed split. `Schedule.listTab` is the single source of truth
//  for both the list tabs and the detail header pill: Completed stays day-granular off the end
//  date (a schedule ending today is not yet completed, one that ended yesterday is), and a
//  schedule whose start date + time has passed is Ongoing rather than Upcoming.
//

import Foundation
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleTabBucketingTests {

    // MARK: - Fixtures

    /// `Schedule` has a synthesized memberwise init over ~28 fields, so rows are decoded from JSON
    /// the way the list endpoint delivers them.
    private func schedule(
        startDate: String? = "2026-08-10T00:00:00",
        startTime: String? = "09:00:00",
        endDate: String?
    ) throws -> ScheduleListDataModel.Schedule {
        let startValue = startDate.map { "\"\($0)\"" } ?? "null"
        let startTimeValue = startTime.map { "\"\($0)\"" } ?? "null"
        let endValue = endDate.map { "\"\($0)\"" } ?? "null"
        let json = """
        {
          "id": 4122,
          "scheduleCode": "SCH-4122",
          "moduleName": "Advanced iOS",
          "courseName": "Swift Programming",
          "startDate": \(startValue),
          "endDate": \(endValue),
          "startTime": \(startTimeValue),
          "endTime": "17:00:00",
          "city": "Pune",
          "placeName": "Main Hall",
          "academyAgencyName": "Enthralltech",
          "participantsCount": 12
        }
        """
        return try JSONDecoder().decode(
            ScheduleListDataModel.Schedule.self,
            from: Data(json.utf8)
        )
    }

    private func apiDate(daysFromToday: Int, dateOnly: Bool = false) -> String {
        let day = Calendar.current.date(
            byAdding: .day,
            value: daysFromToday,
            to: Calendar.current.startOfDay(for: Date())
        )!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = dateOnly ? "yyyy-MM-dd" : "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: day)
    }

    /// Fixed clock for the pill tests — local time, matching `parseAPIDate`.
    private func date(_ raw: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: raw)!
    }

    // MARK: - The tab split

    @Test func pastEndDateIsCompleted() throws {
        let row = try schedule(endDate: apiDate(daysFromToday: -1))

        #expect(row.isUpcoming == false)
        #expect(row.statusText == "Completed")
    }

    /// The regression that kept finished courses out of the Completed tab: the API sometimes sends
    /// a date-only `endDate`, which the old strict `"yyyy-MM-dd'T'HH:mm:ss"` parser dropped to
    /// `nil` — and a `nil` end date reads as upcoming.
    @Test func pastDateOnlyEndDateIsCompleted() throws {
        let row = try schedule(endDate: apiDate(daysFromToday: -3, dateOnly: true))

        #expect(row.endDateValue != nil)
        #expect(row.isUpcoming == false)
        #expect(row.statusText == "Completed")
    }

    @Test func endDateTodayIsStillUpcoming() throws {
        let row = try schedule(endDate: apiDate(daysFromToday: 0))

        #expect(row.isUpcoming)
    }

    /// Day-granular on both sides: a time-of-day earlier than "now" on the end date does not tip
    /// the row into Completed.
    @Test func endDateEarlierTodayIsStillUpcoming() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'"
        let row = try schedule(endDate: formatter.string(from: today) + "00:01:00")

        #expect(row.isUpcoming)
    }

    @Test func futureEndDateIsUpcoming() throws {
        let row = try schedule(endDate: apiDate(daysFromToday: 7))

        #expect(row.isUpcoming)
    }

    @Test(arguments: [nil, "", "not-a-date"] as [String?])
    func unparseableEndDateReadsAsUpcoming(_ raw: String?) throws {
        let row = try schedule(endDate: raw)

        #expect(row.endDateValue == nil)
        #expect(row.isUpcoming)
    }

    // MARK: - The three-way split (Upcoming → Ongoing → Completed)

    /// The bug: a course whose start time had passed still showed "Upcoming" on the detail
    /// screen. Once start date + time is reached the schedule is Ongoing.
    @Test func startTimePassedIsOngoing() throws {
        let row = try schedule(endDate: "2026-08-11T00:00:00")

        #expect(row.hasStarted(now: date("2026-08-10T09:00:00")))
        #expect(row.listTab(now: date("2026-08-10T09:00:00")) == .ongoing)
        #expect(row.statusText(now: date("2026-08-10T09:00:00")) == "Ongoing")
        #expect(row.statusText(now: date("2026-08-10T18:00:00")) == "Ongoing")
    }

    @Test func beforeStartTimeIsUpcoming() throws {
        let row = try schedule(endDate: "2026-08-11T00:00:00")
        let now = date("2026-08-10T08:59:00")

        #expect(row.hasStarted(now: now) == false)
        #expect(row.listTab(now: now) == .upcoming)
        #expect(row.statusText(now: now) == "Upcoming")
    }

    @Test func beforeStartDayIsUpcoming() throws {
        let row = try schedule(endDate: "2026-08-11T00:00:00")

        #expect(row.listTab(now: date("2026-08-09T12:00:00")) == .upcoming)
    }

    /// Completed wins over Ongoing: once the end day has passed the schedule is Completed,
    /// day-granular as before.
    @Test func endDayPassedIsCompleted() throws {
        let row = try schedule(endDate: "2026-08-11T00:00:00")

        #expect(row.listTab(now: date("2026-08-12T00:00:00")) == .completed)
        #expect(row.statusText(now: date("2026-08-12T00:00:00")) == "Completed")
    }

    /// On a day inside the range but before the daily start time, the schedule has still started.
    @Test func middleOfRangeIsOngoing() throws {
        let row = try schedule(endDate: "2026-08-14T00:00:00")

        #expect(row.listTab(now: date("2026-08-12T07:00:00")) == .ongoing)
    }

    /// A missing or unparseable start time falls back to the start of the day — the schedule
    /// counts as started once its start date arrives.
    @Test(arguments: [nil, "", "later"] as [String?])
    func missingStartTimeIsDayGranular(_ raw: String?) throws {
        let row = try schedule(startTime: raw, endDate: "2026-08-11T00:00:00")

        #expect(row.listTab(now: date("2026-08-10T00:00:00")) == .ongoing)
        #expect(row.listTab(now: date("2026-08-09T23:59:00")) == .upcoming)
    }

    /// The API sometimes drops the seconds from times.
    @Test func shortStartTimeParses() throws {
        let row = try schedule(startTime: "09:00", endDate: "2026-08-11T00:00:00")

        #expect(row.listTab(now: date("2026-08-10T09:01:00")) == .ongoing)
        #expect(row.listTab(now: date("2026-08-10T08:59:00")) == .upcoming)
    }

    @Test func unparseableStartDateReadsAsUpcoming() throws {
        let row = try schedule(startDate: "not-a-date", endDate: "2026-08-11T00:00:00")

        #expect(row.startDateTimeValue == nil)
        #expect(row.hasStarted(now: date("2026-08-10T12:00:00")) == false)
        #expect(row.listTab(now: date("2026-08-10T12:00:00")) == .upcoming)
    }

    // MARK: - The request has to ask for past schedules

    /// `showAllData: "false"` makes the server withhold past schedules, which left the Completed
    /// tab with nothing to filter out of the response no matter how many pages were walked.
    @Test func listPayloadAsksForAllData() throws {
        let payload = ScheduleListDataModel.ListPayload(
            page: 1,
            pageSize: 10,
            search: nil,
            searchText: nil,
            showAllData: "true"
        )
        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["showAllData"] as? String == "true")
    }

    /// The count has to be taken over the same population as the list, or the two disagree.
    @Test func countRequestAsksForAllData() {
        #expect(ScheduleListDataModel.ScheduleCountRequest().showAllData == "true")
        #expect(ScheduleListDataModel.ScheduleCountRequest().path.hasSuffix("/null/null/true"))
    }
}
