//
//  ScheduleParticipantCountTests.swift
//  Create_Schedule_KitTests
//
//  Pins the participant-count endpoint and its exact request body.
//

import Foundation
import NetworkService
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleParticipantCountTests {

    @Test func routeMatchesNominateUserCountEndpoint() {
        let request = ScheduleListDataModel.GetNominateUserCountRequest()

        #expect(request.path == "/api/v1/TrainingNomination/GetNominateUserCount")
        #expect(request.method == .post)
        #expect(request.headers == nil)
    }

    @Test func payloadMatchesTheDocumentedContractIncludingNulls() throws {
        let payload = ScheduleListDataModel.NominateUserCountPayload(
            scheduleID: 4122,
            courseId: 59245,
            moduleId: 0,
            page: 1,
            pageSize: 10,
            search: "userName",
            searchText: nil,
            search1: nil,
            searchText1: nil,
            type: nil
        )
        let data = try JSONEncoder().encode(payload)
        let object = try #require(
            JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any]
        )

        #expect(object.count == 10)
        #expect(object["scheduleID"] as? Int == 4122)
        #expect(object["courseId"] as? Int == 59245)
        #expect(object["moduleId"] as? Int == 0)
        #expect(object["page"] as? Int == 1)
        #expect(object["pageSize"] as? Int == 10)
        #expect(object["search"] as? String == "userName")
        #expect(object["searchText"] is NSNull)
        #expect(object["search1"] is NSNull)
        #expect(object["searchText1"] is NSNull)
        #expect(object["Type"] is NSNull)
    }
}
