//
//  ScheduleUsersTests.swift
//  Create_Schedule_KitTests
//
//  The waiting list and the availability roster share one screen, one body and one row.
//  These pin the parts that have to match the server: the three routes, the 10-key body
//  with its explicit nulls, and what each mode is.
//

import Testing
import Foundation
import NetworkService
@testable import Create_Schedule_Kit

@Suite struct ScheduleUsersTests {

    private typealias DM = ScheduleUsersDataModel

    // MARK: - Routes

    @Test func routesMatchTheDocumentedEndpoints() {
        #expect(DM.GetUsersForWaitingRequest().path == "/api/v1/ILTTrainingAttendance/GetUsersForWaiting")
        #expect(DM.GetUsersForAttendanceRequest().path == "/api/v1/ILTTrainingAttendance/GetUsersForAttendance")
        #expect(DM.GetUsersCountForAttendanceRequest().path == "/api/v1/ILTTrainingAttendance/GetUsersCountForAttendance")
    }

    @Test func everyRouteIsAPost() {
        #expect(DM.GetUsersForWaitingRequest().method == .post)
        #expect(DM.GetUsersForAttendanceRequest().method == .post)
        #expect(DM.GetUsersCountForAttendanceRequest().method == .post)
    }

    // MARK: - Body

    private func encodeToObject(_ payload: DM.UsersPayload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return try #require(object as? [String: Any])
    }

    private func payload(search: String? = nil, searchText: String? = nil) -> DM.UsersPayload {
        .init(
            scheduleID: 4307, courseId: 59258, moduleId: 0, page: 1, pageSize: 10,
            search: search, searchText: searchText, search1: nil, searchText1: nil, type: nil
        )
    }

    @Test func bodyMatchesTheDocumentedContractIncludingNulls() throws {
        let object = try encodeToObject(payload(search: "userName"))

        #expect(object.count == 10)
        #expect(object["scheduleID"] as? Int == 4307)
        #expect(object["courseId"] as? Int == 59258)
        #expect(object["moduleId"] as? Int == 0)
        #expect(object["page"] as? Int == 1)
        #expect(object["pageSize"] as? Int == 10)
        #expect(object["search"] as? String == "userName")
        // The nullable filters go out as explicit nulls, not omitted keys.
        #expect(object["searchText"] is NSNull)
        #expect(object["search1"] is NSNull)
        #expect(object["searchText1"] is NSNull)
        #expect(object["Type"] is NSNull)
    }

    @Test func anEmptySearchSendsNeitherHalfOfThePair() throws {
        let object = try encodeToObject(payload())
        #expect(object["search"] is NSNull)
        #expect(object["searchText"] is NSNull)
    }

    @Test func aTypedQuerySendsBothHalves() throws {
        let object = try encodeToObject(payload(search: "userName", searchText: "sunny"))
        #expect(object["search"] as? String == "userName")
        #expect(object["searchText"] as? String == "sunny")
    }

    // MARK: - Modes

    @Test func eachModeCarriesItsOwnCopy() {
        #expect(DM.Mode.waiting.title == "Waiting List")
        #expect(DM.Mode.waiting.sectionTitle == "WAITING")
        #expect(DM.Mode.waiting.emptyMessage == "No one is on the waiting list")
        #expect(DM.Mode.waiting.emptyIcon == "hourglass")

        #expect(DM.Mode.availability.title == "Users Availability")
        #expect(DM.Mode.availability.sectionTitle == "USERS")
        #expect(DM.Mode.availability.emptyMessage == "No users found")
        #expect(DM.Mode.availability.emptyIcon == "person.2")
    }

    @Test func onlyAvailabilityNeedsASecondCallForItsTotal() {
        // The waiting envelope reports `totalRecords` itself.
        #expect(DM.Mode.waiting.needsSeparateCountCall == false)
        #expect(DM.Mode.availability.needsSeparateCountCall)
    }

    @Test func neitherModeSendsTheNomineeType() {
        // `Type: "Attandance"` is the *nominee* query on the same route; both of these
        // lists send null and get the wider set.
        #expect(DM.Mode.allCases.allSatisfy { $0.apiType == nil })
    }

    // MARK: - Decoding

    /// The availability response, verbatim from UAT (trimmed to two rows).
    private static let availabilityJSON = """
    [
      {"id":12277,"scheduleID":4307,"referenceRequestID":null,"requestCode":null,
       "userId":"sunny","userName":"Sunny Rasal","emailId":"sunny.rasal@dummy.com",
       "mobileNumber":"xxxxxxxxxx","status":"True","isPresent":false,"moduleID":46404,
       "courseID":59258,"trainingRequestStatus":"Pending","attendanceStatus":null,
       "noticePeriod":null,"overAllStatus":"NotStarted","attendanceDate":null,
       "config9":null,"division":null,"userprofile":null},
      {"id":12275,"scheduleID":4307,"referenceRequestID":null,"requestCode":null,
       "userId":"raghavendra","userName":"Raghavendra Billawa",
       "emailId":"raghavendra.billawa@dummy.com","mobileNumber":"xxxxxxxxxx",
       "status":"False","isPresent":false,"moduleID":46404,"courseID":59258,
       "trainingRequestStatus":"Pending","attendanceStatus":null,"noticePeriod":null,
       "overAllStatus":"","attendanceDate":null,"config9":null,"division":null,
       "userprofile":null}
    ]
    """

    @Test func availabilityRowsDecodeFromTheLiveResponse() throws {
        let users = try JSONDecoder().decode([DM.ScheduleUser].self, from: Data(Self.availabilityJSON.utf8))

        #expect(users.count == 2)
        let sunny = try #require(users.first)
        #expect(sunny.displayName == "Sunny Rasal")
        #expect(sunny.initials == "SR")
        #expect(sunny.emailId == "sunny.rasal@dummy.com")
        #expect(sunny.mobileNumber == "xxxxxxxxxx")
        // `status: "True"` is an accepted nomination.
        #expect(sunny.isConfirmed)
        #expect(sunny.statusText == "Confirmed")
        // Not yet accepted — the pill the screen shows.
        #expect(users[1].isConfirmed == false)
        #expect(users[1].statusText == "Pending")
    }

    @Test func aRowWithNoRequestStatusStillReadsAsPending() throws {
        let json = #"{"id":1,"userId":"kim","userName":"Kim","status":"False"}"#
        let user = try JSONDecoder().decode(DM.ScheduleUser.self, from: Data(json.utf8))
        #expect(user.statusText == "Pending")
        #expect(user.initials == "K")
    }

    @Test func theWaitingEnvelopeUnwrapsItsRowsAndTotal() throws {
        let json = """
        {"totalRecords":2,"waitingdata":\(Self.availabilityJSON)}
        """
        let response = try JSONDecoder().decode(DM.WaitingResponse.self, from: Data(json.utf8))

        #expect(response.totalRecords == 2)
        #expect(response.users.count == 2)
        #expect(response.users.first?.displayName == "Sunny Rasal")
    }

    @Test func anEmptyWaitingListDecodesToNoRows() throws {
        let response = try JSONDecoder().decode(
            DM.WaitingResponse.self,
            from: Data(#"{"totalRecords":0,"waitingdata":[]}"#.utf8)
        )
        #expect(response.totalRecords == 0)
        #expect(response.users.isEmpty)
    }

    @Test func aMissingWaitingArrayIsTreatedAsEmpty() throws {
        // Defensive: the screen must show its empty state, not crash, if the key is absent.
        let response = try JSONDecoder().decode(DM.WaitingResponse.self, from: Data("{}".utf8))
        #expect(response.users.isEmpty)
    }
}
