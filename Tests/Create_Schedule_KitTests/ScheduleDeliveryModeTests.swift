//
//  ScheduleDeliveryModeTests.swift
//  Create_Schedule_KitTests
//
//  Pins the Online/Offline row on the Schedule Details header.
//

import Foundation
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleDeliveryModeTests {

    private typealias Schedule = ScheduleListDataModel.Schedule

    // MARK: - The mode rule

    @Test func webinarFlagReadsAsOnline() {
        #expect(Schedule.deliveryText(isWebinar: true, webinarType: nil, city: "Gujrat") == "Online · Gujrat")
    }

    @Test func webinarTypeAloneReadsAsOnline() {
        #expect(Schedule.deliveryText(isWebinar: nil, webinarType: "zoom", city: "Gujrat") == "Online · Gujrat")
    }

    @Test func noWebinarSignalReadsAsOffline() {
        #expect(Schedule.deliveryText(isWebinar: false, webinarType: nil, city: "Gujrat") == "Offline · Gujrat")
        #expect(Schedule.deliveryText(isWebinar: nil, webinarType: "", city: "Gujrat") == "Offline · Gujrat")
    }

    @Test func cityIsOmittedWhenAbsent() {
        #expect(Schedule.deliveryText(isWebinar: true, webinarType: nil, city: nil) == "Online")
        #expect(Schedule.deliveryText(isWebinar: true, webinarType: nil, city: "") == "Online")
    }

    // MARK: - The reported bug

    @Test func listRowWithoutWebinarFieldsFallsBackToOffline() throws {
        let row = try decodeRow(extraFields: "")
        #expect(row.deliveryText == "Offline · Gujrat")
    }

    @Test func detailResponseSuppliesTheOnlineMode() throws {
        let details = try JSONDecoder().decode(
            EditScheduleDataModel.ScheduleDetailsResponse.self,
            from: Data(#"{"id":8533,"city":"Gujrat","isWebinar":true,"webinarType":"teams"}"#.utf8)
        )
        #expect(details.isWebinar == true)
        #expect(Schedule.deliveryText(
            isWebinar: details.isWebinar,
            webinarType: details.webinarType,
            city: details.city
        ) == "Online · Gujrat")
    }

    @Test func listRowWithWebinarFlagReadsAsOnline() throws {
        let row = try decodeRow(extraFields: #","isWebinar":true"#)
        #expect(row.deliveryText == "Online · Gujrat")
    }

    // MARK: - Schedule Info values

    @Test func seatCapacityPrefersTheStringThenTheNumber() {
        #expect(Schedule.seatCapacityText(seatCapacity: "25", scheduleCapacity: nil) == "25")
        #expect(Schedule.seatCapacityText(seatCapacity: nil, scheduleCapacity: 30) == "30")
        #expect(Schedule.seatCapacityText(seatCapacity: "", scheduleCapacity: 30) == "30")
    }

    @Test func seatCapacityIsDashWhenNeitherSourceHasAValue() {
        #expect(Schedule.seatCapacityText(seatCapacity: nil, scheduleCapacity: nil) == "-")
        #expect(Schedule.seatCapacityText(seatCapacity: "", scheduleCapacity: 0) == "-")
    }

    @Test func coordinatorIsDashWhenAbsent() {
        #expect(Schedule.coordinatorText(contactPersonName: "Sachin Shimpi") == "Sachin Shimpi")
        #expect(Schedule.coordinatorText(contactPersonName: nil) == "-")
        #expect(Schedule.coordinatorText(contactPersonName: "") == "-")
    }

    @Test func listRowCarriesNoSeatCapacityOrCoordinator() throws {
        let row = try decodeRow(extraFields: "")
        #expect(row.seatCapacityText == "-")
        #expect(row.coordinator == "-")
    }

    @Test func detailResponseSuppliesSeatCapacityAndCoordinator() throws {
        let details = try JSONDecoder().decode(
            EditScheduleDataModel.ScheduleDetailsResponse.self,
            from: Data(#"{"id":8631,"seatCapacity":"25","scheduleCapacity":25,"contactPersonName":"Sachin Shimpi"}"#.utf8)
        )
        #expect(Schedule.seatCapacityText(
            seatCapacity: details.seatCapacity,
            scheduleCapacity: details.scheduleCapacity
        ) == "25")
        #expect(Schedule.coordinatorText(contactPersonName: details.contactPersonName) == "Sachin Shimpi")
    }

    // MARK: - Fixture

    private func decodeRow(extraFields: String) throws -> Schedule {
        let json = """
        {
          "id": 8533,
          "scheduleCode": "SC8533",
          "moduleName": "19956_New java online classes for beginner",
          "courseName": "Java",
          "startDate": "2026-08-19T00:00:00",
          "endDate": "2026-08-19T00:00:00",
          "startTime": "11:25:00",
          "endTime": "11:45:00",
          "city": "Gujrat",
          "placeName": "Gujrat tech",
          "academyAgencyName": "Gujrat tech"\(extraFields)
        }
        """
        return try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
    }
}
