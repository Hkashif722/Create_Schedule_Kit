import Testing
import Foundation
@testable import Create_Schedule_Kit

/// Encoding tests for the `ILTSchedule/GetScheduleData` list body, pinned against the request
/// the web client sends when its "Filter" dropdown + search box are used:
/// `{Page: 1, PageSize: 10, Search: "moduleName", searchText: "aa", showAllData: "false"}`.
///
/// `showAllData` is the one deliberate difference: the package sends `"true"` so the server does
/// not withhold past schedules, which the Completed tab needs.
@Suite struct ScheduleListSearchPayloadTests {

    private func encodeToObject(_ payload: ScheduleListDataModel.ListPayload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func payload(column: ScheduleListDataModel.FilterColumn?, text: String?) -> ScheduleListDataModel.ListPayload {
        ScheduleListDataModel.ListPayload(
            page: 1,
            pageSize: 10,
            search: column?.apiValue,
            searchText: text,
            showAllData: "true"
        )
    }

    @Test func searchSendsTheColumnAlongsideTheText() throws {
        let object = try encodeToObject(payload(column: .moduleName, text: "aa"))
        #expect(object["Page"] as? Int == 1)
        #expect(object["PageSize"] as? Int == 10)
        #expect(object["Search"] as? String == "moduleName")
        #expect(object["searchText"] as? String == "aa")
        #expect(object["showAllData"] as? String == "true")
    }

    /// The bug this replaced: a nil optional is *omitted* by the synthesized encoder, so a body
    /// carrying `searchText` with no `Search` key reached the server and was ignored — the search
    /// box looked wired up but never filtered.
    @Test func aTextWithoutAColumnWouldNotEvenSendTheSearchKey() throws {
        let object = try encodeToObject(payload(column: nil, text: "aa"))
        #expect(object["Search"] == nil)
        #expect(object["searchText"] as? String == "aa")
    }

    @Test func anEmptySearchOmitsBothKeys() throws {
        let object = try encodeToObject(payload(column: nil, text: nil))
        #expect(object["Search"] == nil)
        #expect(object["searchText"] == nil)
        #expect(object["Page"] as? Int == 1)
    }

    /// The dropdown's labels and the values sent as `Search`, in the web client's order.
    @Test func filterColumnsMirrorTheWebDropdown() {
        let columns = ScheduleListDataModel.FilterColumn.allCases
        #expect(columns.map(\.title) == [
            "Module Name", "Schedule Code", "Course Name", "Academy Name", "Schedule Type", "Created By"
        ])
        #expect(columns.map(\.apiValue) == [
            "moduleName", "scheduleCode", "courseName", "academyAgencyName", "scheduleType", "createdBy"
        ])
    }
}
