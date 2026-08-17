import Testing
import Foundation
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

    @Test func attendanceDeleteResponseDecodesAsBareBool() throws {
        #expect(try JSONDecoder().decode(Bool.self, from: Data("true".utf8)))
        #expect(try JSONDecoder().decode(Bool.self, from: Data("false".utf8)) == false)
    }

    // MARK: - Schedule Detail

    @Test func deleteNominationPayloadMatchesServerKeys() throws {
        let object = try encodeToObject(
            ScheduleDetailDataModel.DeleteNominationPayload(
                scheduleID: 3893,
                courseId: 35038,
                moduleId: 23050,
                userIdEncrypted: "ZEvFYe8WFCkqdvwmYOQIaw=="
            )
        )

        #expect(object.count == 4)
        #expect(object["scheduleID"] as? Int == 3893)
        #expect(object["courseId"] as? Int == 35038)
        #expect(object["moduleId"] as? Int == 23050)
        // The encrypted id is opaque and must survive verbatim.
        #expect(object["UserIdEncrypted"] as? String == "ZEvFYe8WFCkqdvwmYOQIaw==")
    }

    @Test func encryptedUserIdIsBuiltFromTheNumericRowId() throws {
        // The list returns `userId` as a plain login name ("anu"), so the encrypted value
        // sent to DeleteUserNomination is derived from the numeric row id instead.
        let encrypted = EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "11892")
        #expect(!encrypted.isEmpty)
        #expect(encrypted != "11892")
        #expect(encrypted != "anu")
        #expect(EncryptDecryptUtility.shared.newDecryptString(responseStr: encrypted) == "11892")
    }
}
