//
//  ScheduleTabBucketingTests.swift
//  Create_Schedule_KitTests
//
//  Pins the Upcoming/Completed split. `Schedule.isUpcoming` is the single source of truth for
//  both the list tabs and the detail header pill, and the rule is day-granular off the end date:
//  a schedule ending today is still upcoming, one that ended yesterday is completed.
//

import Foundation
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleTabBucketingTests {

    // MARK: - Fixtures

    /// `Schedule` has a synthesized memberwise init over ~28 fields, so rows are decoded from JSON
    /// the way the list endpoint delivers them.
    private func schedule(endDate: String?) throws -> ScheduleListDataModel.Schedule {
        let endValue = endDate.map { "\"\($0)\"" } ?? "null"
        let json = """
        {
          "id": 4122,
          "scheduleCode": "SCH-4122",
          "moduleName": "Advanced iOS",
          "courseName": "Swift Programming",
          "startDate": "2026-08-10T00:00:00",
          "endDate": \(endValue),
          "startTime": "09:00:00",
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

    // MARK: - The split

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
        #expect(row.statusText == "Upcoming")
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
        #expect(row.statusText == "Upcoming")
    }

    @Test(arguments: [nil, "", "not-a-date"] as [String?])
    func unparseableEndDateReadsAsUpcoming(_ raw: String?) throws {
        let row = try schedule(endDate: raw)

        #expect(row.endDateValue == nil)
        #expect(row.isUpcoming)
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
