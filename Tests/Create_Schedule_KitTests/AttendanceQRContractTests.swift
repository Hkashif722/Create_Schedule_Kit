//
//  AttendanceQRContractTests.swift
//  Create_Schedule_KitTests
//
//  The QR wire contract, pinned before a camera is ever opened: what a scanned profile QR
//  must contain, the 13-key mark body, which route the role picks, and the two response
//  shapes the endpoint answers with.
//

import Testing
import Foundation
import NetworkService
@testable import Create_Schedule_Kit

@Suite struct AttendanceQRContractTests {

    private typealias QR = AttendanceQRDataModel

    // MARK: - Reading a profile QR

    /// A learner's profile QR as it actually reaches the scanner. The generator writes the
    /// profile fields raw, and the server encrypts two of them: `UserId` and `UserEmail`
    /// arrive AES-encrypted, `Id` and `UserName` are plain.
    private static let profileQRJSON = """
    {"Id":"11998","UserId":"INISu97c5utzCRj1Jkpsiw==","UserName":"Sunny Rasal","UserEmail":"ENC_EMAIL=="}
    """

    @Test func aProfileQRDecodesItsFourKeys() throws {
        let payload = try #require(QR.ProfileQRPayload.decode(Self.profileQRJSON))

        #expect(payload.id == "11998")
        #expect(payload.userId == "INISu97c5utzCRj1Jkpsiw==")
        #expect(payload.userName == "Sunny Rasal")
        #expect(payload.userEmail == "ENC_EMAIL==")
        #expect(payload.displayName == "Sunny Rasal")
    }

    /// `userId` is encrypted, so it must never be shown raw when the QR carries no name —
    /// the confirm popup would read as base64 gibberish.
    @Test func anEncryptedIdIsNeverShownAsTheDisplayName() throws {
        let payload = try #require(QR.ProfileQRPayload.decode(#"{"UserId":"INISu97c5utzCRj1Jkpsiw=="}"#))
        #expect(payload.displayName != payload.userId)
    }

    @Test func theUserIdStaysAStringAndIsNotCoercedToAnInt() throws {
        // It travels as `EUserID`, which the server reads as an encrypted string.
        let payload = try #require(QR.ProfileQRPayload.decode(Self.profileQRJSON))
        #expect(payload.userId == "INISu97c5utzCRj1Jkpsiw==")
    }

    @Test(arguments: [
        "",
        "   ",
        "not json at all",
        #"{"ModuleId":1,"ScheduleId":2}"#,   // a schedule QR, not a profile one
        #"{"UserId":""}"#,                    // present but empty
        #"{"UserName":"Sunny"}"#              // no id to mark against
    ])
    func anythingThatIsNotAProfileQRIsRejected(_ scanned: String) {
        #expect(QR.ProfileQRPayload.decode(scanned) == nil)
    }

    // MARK: - The mark body

    private func markItem(
        eUserID: String = "sunny",
        mobileNumber: String = "9876543210"
    ) -> QR.MarkFromProfileQRItem {
        .init(
            eUserID: eUserID,
            moduleId: 46404,
            scheduleId: 4307,
            courseId: 59258,
            courseTitle: "ELGI Live Class",
            attendanceDate: "2026-09-09T00:00:00",
            mobileNumber: mobileNumber
        )
    }

    private func encodeToObject(_ item: QR.MarkFromProfileQRItem) throws -> [String: Any] {
        let data = try JSONEncoder().encode(item)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func theMarkBodyCarriesTheThirteenServerKeys() throws {
        let object = try encodeToObject(markItem())

        #expect(object.count == 13)
        #expect(object["IsPresent"] as? Int == 1)
        #expect(object["EUserID"] as? String == "sunny")
        #expect(object["UserId"] as? Int == 0)
        #expect(object["moduleId"] as? Int == 46404)
        #expect(object["scheduleId"] as? Int == 4307)
        #expect(object["courseId"] as? Int == 59258)
        #expect(object["CourseTitle"] as? String == "ELGI Live Class")
        #expect(object["OTP"] as? String == "")
        #expect(object["isWeb"] as? Int == 0)
        #expect(object["AttendanceStatus"] as? String == "ATTD")
        #expect(object["attendanceDate"] as? String == "2026-09-09T00:00:00")
        #expect(object["id"] as? Int == 0)
        #expect(object["MobileNumber"] as? String == "9876543210")
    }

    @Test func aScanAlwaysMarksAttended() throws {
        // There is no status picker in the scan flow: a scan means the person is present.
        let object = try encodeToObject(markItem())
        #expect(object["AttendanceStatus"] as? String == AttendanceDataModel.StatusCode.attended)
        #expect(object["IsPresent"] as? Int == 1)
    }

    /// The server sample carries both flags as integers. JSON `true` and `1` are different
    /// tokens, so this pins the encoded form rather than the Swift type.
    @Test func theTwoFlagsAreIntegersNotBooleans() throws {
        let data = try JSONEncoder().encode(markItem())
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"IsPresent\":1"))
        #expect(json.contains("\"isWeb\":0"))
        #expect(!json.contains("true"))
        #expect(!json.contains("false"))
    }

    @Test func theScannedIdTravelsAsEUserIDWhileUserIdStaysZero() throws {
        let object = try encodeToObject(markItem(eUserID: "raghavendra"))
        #expect(object["EUserID"] as? String == "raghavendra")
        #expect(object["UserId"] as? Int == 0)
    }

    /// The QR's id is already encrypted and the endpoint expects it exactly as scanned.
    /// Encrypting it again, or decrypting it to a login id, resolves to nobody — which the
    /// server reports as "User is not nominated for the schedule".
    @Test func theEncryptedIdReachesEUserIDUntouched() throws {
        let payload = try #require(QR.ProfileQRPayload.decode(Self.profileQRJSON))
        let object = try encodeToObject(markItem(eUserID: payload.userId))

        #expect(object["EUserID"] as? String == "INISu97c5utzCRj1Jkpsiw==")
        #expect(object["UserId"] as? Int == 0)
    }

    /// Same rule as `EUserID`: encrypted at source, passed through untouched. Decrypting
    /// it here — or encrypting an already-encrypted value again — sends a number the
    /// server cannot read.
    @Test func theMobileNumberIsCarriedVerbatim() throws {
        let encrypted = "z/EkAs6KrAw0TFsUNW0/Zw=="
        let object = try encodeToObject(markItem(mobileNumber: encrypted))
        #expect(object["MobileNumber"] as? String == encrypted)
    }

    @Test func courseIdIsAnIntNotAnArray() throws {
        // The reference carries a comment claiming this becomes an array. It does not.
        let object = try encodeToObject(markItem())
        #expect(object["courseId"] as? Int == 59258)
        #expect(object["courseId"] as? [Int] == nil)
    }

    @Test func theDateCarriesNoTimezoneMarker() throws {
        // A trailing `Z` makes the server shift the day out of the one the user picked.
        let object = try encodeToObject(markItem())
        let date = try #require(object["attendanceDate"] as? String)
        #expect(!date.hasSuffix("Z"))
        #expect(!date.contains("."))
        #expect(date == "2026-09-09T00:00:00")
    }

    @Test func theMobileNumberComesFromTheHostAndMayBeEmpty() throws {
        #expect(try encodeToObject(markItem(mobileNumber: "")).count == 13)
        #expect(try encodeToObject(markItem(mobileNumber: ""))["MobileNumber"] as? String == "")
    }

    @Test func theBodyIsPostedAsATopLevelArray() throws {
        let data = try JSONEncoder().encode([markItem()])
        let array = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(array.count == 1)
    }

    // MARK: - Route by role

    @Test func aTrainerOrAdminMarksOnTheBareControllerPath() {
        #expect(QR.AdminMarkAttendanceRequest().path == "/api/v1/ILTTrainingAttendance")
        #expect(QR.AdminMarkAttendanceRequest().method == .post)
    }

    @Test func anEndUserMarksOnTheUpdateSubPath() {
        #expect(QR.EndUserMarkAttendanceRequest().path
                == "/api/v1/ILTTrainingAttendance/UpdateILTTrainingAttendance")
        #expect(QR.EndUserMarkAttendanceRequest().method == .post)
    }

    @Test(arguments: ["eu", "EU", " Eu "])
    func theEndUserRoleIsMatchedCaseInsensitivelyAndTrimmed(_ role: String) {
        #expect(QR.isEndUser(role: role))
    }

    @Test(arguments: ["", "ET", "ADMIN", "trainer"])
    func everyOtherRoleUsesTheAdminRoute(_ role: String) {
        #expect(QR.isEndUser(role: role) == false)
    }

    // MARK: - Response shapes

    private func response(_ json: String) throws -> QR.MarkAttendanceResponse {
        try JSONDecoder().decode(QR.MarkAttendanceResponse.self, from: Data(json.utf8))
    }

    @Test func aBareTrueIsASuccess() throws {
        let result = try response("true")
        #expect(result.isSuccess)
        #expect(result.failureMessage == nil)
    }

    @Test func aBareFalseIsAFailureWithFallbackCopy() throws {
        let result = try response("false")
        #expect(result.isSuccess == false)
        #expect(result.failureMessage?.isEmpty == false)
    }

    @Test func anEnvelopeWithTwoHundredIsASuccess() throws {
        let result = try response(#"{"statusCode":200,"message":null,"description":"success"}"#)
        #expect(result.isSuccess)
    }

    @Test func anEnvelopeWithANonSuccessCodeCarriesItsDescription() throws {
        let result = try response(#"{"statusCode":400,"description":"Attendance for the user already exists."}"#)
        #expect(result.isSuccess == false)
        #expect(result.failureMessage == "Attendance for the user already exists.")
    }

    /// The reference reads this as a success, which is the bug this pins shut.
    @Test func aTwoHundredCarryingARejectedRowIsNotASuccess() throws {
        let json = """
        {"statusCode":200,"description":"success","aPINominationResponses":[
          {"scheduleCode":"SC9202","userId":"sunny","userName":"Sunny Rasal",
           "status":"Failed","errorMessage":"Attendance already marked for this date."}]}
        """
        let result = try response(json)

        #expect(result.isSuccess == false)
        #expect(result.failureMessage == "Attendance already marked for this date.")
    }

    @Test func aTwoHundredWithAnAcceptedRowIsASuccess() throws {
        let json = """
        {"statusCode":200,"aPINominationResponses":[
          {"scheduleCode":"SC9202","userId":"sunny","status":"Success","errorMessage":null}]}
        """
        #expect(try response(json).isSuccess)
    }

    @Test func aRowWhoseStatusReadsAsARefusalIsRejectedEvenWithoutAMessage() throws {
        let json = """
        {"statusCode":200,"aPINominationResponses":[{"userId":"sunny","status":"Rejected"}]}
        """
        let result = try response(json)
        #expect(result.isSuccess == false)
        #expect(result.failureMessage == "Rejected")
    }

    @Test func theHappyPathWordIsNeverShownAsAFailure() throws {
        let result = try response(#"{"statusCode":500,"description":"success"}"#)
        #expect(result.isSuccess == false)
        #expect(result.failureMessage == nil)   // caller supplies its own copy
    }

    // MARK: - The generated schedule QR

    @Test func theScheduleQRCarriesTheSixServerKeysInPascalCase() throws {
        let payload = QR.ScheduleQRPayload(
            moduleId: 46404, scheduleId: 4307, courseId: 59258,
            courseName: "ELGI Live Class", attendanceDate: "2026-09-09T00:00:00",
            scheduleCode: "SC9202"
        )
        let data = try JSONEncoder().encode(payload)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object.count == 6)
        #expect(object["ModuleId"] as? Int == 46404)
        #expect(object["ScheduleId"] as? Int == 4307)
        #expect(object["CourseId"] as? Int == 59258)
        #expect(object["CourseName"] as? String == "ELGI Live Class")
        #expect(object["AttendanceDate"] as? String == "2026-09-09T00:00:00")
        #expect(object["ScheduleCode"] as? String == "SC9202")
    }
}
