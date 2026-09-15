import Testing
import Foundation
import SwiftfulRouting
import SwiftUIUtilities
@testable import Create_Schedule_Kit

/// Encoding tests for the two delete-user request bodies. Both APIs are case-sensitive
/// about their keys and neither reports a mapping mistake — `DeleteUserNomination`
/// returns an empty body regardless — so the casing is pinned here.
@Suite struct DeleteUserPayloadTests {

    init() {
        // The encrypted-id fallback reads the shared utility environment.
        SwiftUtilityEnvironment.configure(
            SwiftUtilityConfig(
                encryptionDecryptionKey: "preview-key",
                isBlobEnabled: true,
                orgCode: "preview",
                configurableDate: "dd-MM-yyyy",
                baseURL: "",
                lxpOPath: "",
                lxpBlobPath: "",
                lxpBlobPath1: ""
            )
        )
    }

    private func encodeToObject<T: Encodable>(_ payload: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return try #require(object as? [String: Any])
    }

    // MARK: - Update Attendance

    @Test func attendanceDeletePayloadUsesPascalCaseKeys() throws {
        let object = try encodeToObject(
            AttendanceDataModel.AttendanceDeletePayload(userMasterId: 11659, scheduleId: 3737)
        )

        #expect(object.count == 2)
        #expect(object["UserMasterId"] as? Int == 11659)
        #expect(object["ScheduleId"] as? Int == 3737)
        // camelCase variants must not appear — the server ignores them.
        #expect(object["userMasterId"] == nil)
        #expect(object["scheduleId"] == nil)
    }

    /// Delete is gated on the row carrying an overall status; a blank one must not pass.
    @Test(arguments: [
        (String?.none, false),
        (.some(""), false),
        (.some("   "), false),
        (.some("Completed"), true),
        (.some("NotStarted"), true)
    ] as [(String?, Bool)])
    func attendanceDeleteIsGatedOnOverAllStatus(status: String?, canDelete: Bool) {
        #expect(attendanceUser(overAllStatus: status).hasOverAllStatus == canDelete)
    }

    /// Delete is a single-row action, but the copy follows the current selection count.
    @MainActor
    @Test(arguments: [
        (0, "user as attendance status is"),
        (1, "user as attendance status is"),
        (2, "users as attendance statuses are"),
        (5, "users as attendance statuses are")
    ])
    func missingStatusMessagePluralizesOnSelectionCount(selected: Int, fragment: String) {
        // Selection and this copy live on the shared list view model since the flow split.
        let viewModel = AttendanceUsersViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                mode: .bulkMark,
                scheduleID: 3787, courseID: 56288, moduleID: 42182,
                scheduleCode: "SC8432", attendanceDate: Date(),
                onAttendanceChanged: {}
            )
        )
        (1...max(selected, 1)).prefix(selected).forEach {
            viewModel.toggle(attendanceUser(id: $0, overAllStatus: nil))
        }

        #expect(viewModel.missingStatusMessage == "Cannot delete attendance for the selected \(fragment) not present.")
    }

    private func attendanceUser(id: Int = 1, overAllStatus: String?) -> AttendanceDataModel.AttendanceUser {
        .init(
            id: id, scheduleID: 3787, userId: "akk", userName: "AKK",
            emailId: "ak2@gmail.com", mobileNumber: nil, isPresent: false,
            moduleID: 42182, courseID: 56288,
            overAllStatus: overAllStatus, attendanceStatus: nil, attendanceDate: nil
        )
    }

    @Test func attendanceDeleteResponseDecodesAsBareBool() throws {
        #expect(try JSONDecoder().decode(Bool.self, from: Data("true".utf8)))
        #expect(try JSONDecoder().decode(Bool.self, from: Data("false".utf8)) == false)
    }

    // MARK: - Schedule Detail

    /// Verbatim from the working request:
    /// `{"scheduleID":4458,"courseId":59458,"moduleId":46516,"UserIdEncrypted":"12306"}`
    @Test func deleteNominationPayloadMatchesServerKeys() throws {
        let object = try encodeToObject(
            ScheduleDetailDataModel.DeleteNominationPayload(
                scheduleID: 4458,
                courseId: 59458,
                moduleId: 46516,
                userId: "12306"
            )
        )

        #expect(object.count == 4)
        #expect(object["scheduleID"] as? Int == 4458)
        #expect(object["courseId"] as? Int == 59458)
        #expect(object["moduleId"] as? Int == 46516)
        #expect(object["UserIdEncrypted"] as? String == "12306")
    }

    /// `UserIdEncrypted` names the field, not its contents: the value is the nominee row's
    /// plain numeric id. An AES value there matches no user, and the endpoint's empty
    /// response makes that no-op look like a success.
    @Test func theNominationDeleteIdIsNotEncrypted() throws {
        let object = try encodeToObject(
            ScheduleDetailDataModel.DeleteNominationPayload(
                scheduleID: 4458, courseId: 59458, moduleId: 46516, userId: "12306"
            )
        )
        let sent = try #require(object["UserIdEncrypted"] as? String)

        #expect(sent == "12306")
        #expect(Int(sent) == 12306)
        #expect(sent != EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "12306"))
    }
}
