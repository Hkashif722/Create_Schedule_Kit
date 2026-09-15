//
//  AttendanceQRDataModel.swift
//  Create_Schedule_Kit
//
//  The two QR contracts this package speaks:
//
//   • it *reads* a learner's profile QR — `{"Id","UserId","UserName","UserEmail"}` — and
//     marks that learner present;
//   • it *writes* a schedule QR — `{"ModuleId",…,"ScheduleCode"}` — for learners to scan
//     from their own app.
//
//  Key casing below is mixed on purpose: it mirrors the server contract exactly, as
//  captured from the web and the main app.
//

import Foundation
import NetworkService
import SwiftUIUtilities

enum AttendanceQRDataModel {

    // MARK: - What a scanned profile QR contains

    /// A learner's profile QR. `userId` is a **String** on the wire and travels as `EUserID`
    /// on the mark body — it is never coerced to an Int.
    ///
    /// `userEmail` arrives AES-encrypted. It is decrypted for the confirmation popup only
    /// and never posted anywhere.
    struct ProfileQRPayload: Decodable, Equatable {
        let id: String?
        let userId: String
        let userName: String?
        let userEmail: String?

        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case userId = "UserId"
            case userName = "UserName"
            case userEmail = "UserEmail"
        }

        /// `UserName` is the only plain key on the QR, so it is the only one safe to show.
        /// `userId` is AES-encrypted at source, so falling back to it raw would put base64
        /// in front of the trainer; it is decrypted for display, and dropped if that fails.
        var displayName: String {
            if let name = userName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return name
            }
            let decrypted = EncryptDecryptUtility.shared
                .newDecryptString(responseStr: userId)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return decrypted.isEmpty ? "this learner" : decrypted
        }

        /// Decodes a scanned string, or `nil` when it is not a profile QR at all.
        static func decode(_ scanned: String) -> ProfileQRPayload? {
            let trimmed = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
            guard let payload = try? JSONDecoder().decode(ProfileQRPayload.self, from: data),
                  !payload.userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return payload
        }
    }

    // MARK: - What a generated schedule QR contains

    /// Baked into the QR the trainer hands out. The learner app decodes exactly these keys.
    struct ScheduleQRPayload: Encodable, Equatable {
        let moduleId: Int
        let scheduleId: Int
        let courseId: Int
        let courseName: String
        let attendanceDate: String
        let scheduleCode: String

        enum CodingKeys: String, CodingKey {
            case moduleId = "ModuleId"
            case scheduleId = "ScheduleId"
            case courseId = "CourseId"
            case courseName = "CourseName"
            case attendanceDate = "AttendanceDate"
            case scheduleCode = "ScheduleCode"
        }
    }

    // MARK: - Marking from a scan

    /// One row of the mark body, which is posted as a top-level array.
    ///
    /// A scan always means "this person is in the room", so `attendanceStatus` is fixed to
    /// `ATTD` and `isPresent` to `true` — there is no status picker in the scan flow.
    struct MarkFromProfileQRItem: Encodable, Equatable {
        /// `1`, not `true`: the server sample carries these two flags as integers. The
        /// legacy iOS screen sends booleans and marks successfully, so the endpoint takes
        /// either — this matches the documented body exactly.
        var isPresent: Int = 1
        /// The scanned learner's id, exactly as it sat in the QR.
        ///
        /// It arrives AES-encrypted — the profile QR is built from the raw `userId` field,
        /// which the server encrypts — and the endpoint expects it that way. Do not encrypt
        /// it again and do not decrypt it: it is opaque here, as is `mobileNumber`.
        let eUserID: String
        /// Zero for a trainer marking someone else; the scanned learner is identified by
        /// `EUserID` alone.
        var userId: Int = 0
        let moduleId: Int
        let scheduleId: Int
        let courseId: Int
        let courseTitle: String
        var otp: String = ""
        var isWeb: Int = 0
        var attendanceStatus: String = AttendanceDataModel.StatusCode.attended
        /// Zone-less `yyyy-MM-dd'T'HH:mm:ss`, matching the bulk save. A trailing `Z` makes
        /// the server read it as UTC and shift it out of the day the user picked.
        let attendanceDate: String
        var id: Int = 0
        /// The *scanning* user's own number — not the scanned learner's — encrypted, as the
        /// endpoint expects. The host supplies it in the clear, so `encryptedForWire` does
        /// the work on the way in; unlike `eUserID`, which is already encrypted when it
        /// reaches us. Empty when the host has nothing to supply; the key still goes out.
        let mobileNumber: String

        enum CodingKeys: String, CodingKey {
            case isPresent = "IsPresent"
            case eUserID = "EUserID"
            case userId = "UserId"
            case moduleId, scheduleId, courseId
            case courseTitle = "CourseTitle"
            case otp = "OTP"
            case isWeb
            case attendanceStatus = "AttendanceStatus"
            case attendanceDate
            case id
            case mobileNumber = "MobileNumber"
        }
    }

    // MARK: - Response

    /// The route answers either a bare `true`/`false` or an envelope, so both are decoded.
    enum MarkAttendanceResponse: Decodable {
        case simple(Bool)
        case envelope(Envelope)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            // Bool first: an envelope would never decode as one, but a bare `true` *would*
            // decode as an all-optional envelope, silently reading as a failure.
            if let flag = try? container.decode(Bool.self) {
                self = .simple(flag)
                return
            }
            self = .envelope(try container.decode(Envelope.self))
        }

        var isSuccess: Bool {
            switch self {
            case .simple(let flag):    return flag
            case .envelope(let body):  return body.isSuccess
            }
        }

        /// What to show when it did not succeed.
        var failureMessage: String? {
            switch self {
            case .simple(let flag):
                return flag ? nil : "Could not mark attendance. Please try again."
            case .envelope(let body):
                return body.isSuccess ? nil : body.failureMessage
            }
        }

        struct Envelope: Decodable {
            let statusCode: Int?
            let message: String?
            let description: String?
            let aPINominationResponses: [NominationRow]?

            var rows: [NominationRow] { aPINominationResponses ?? [] }

            /// A 200 is not enough: the envelope can report 200 while rejecting the row it
            /// was asked to insert, which the reference implementation reads as success.
            var isSuccess: Bool {
                (statusCode ?? 0) == 200 && !rows.contains { $0.isRejected }
            }

            var failureMessage: String? {
                if let rejection = rows.first(where: { $0.isRejected })?.rejectionReason {
                    return rejection
                }
                for candidate in [message, description] {
                    let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !trimmed.isEmpty, trimmed.caseInsensitiveCompare("success") != .orderedSame
                    else { continue }
                    return trimmed
                }
                return nil
            }
        }

        /// Per-user outcome. The server reports a refused insert here rather than by status
        /// code — an already-marked learner, for instance.
        struct NominationRow: Decodable {
            let scheduleCode: String?
            let userId: String?
            let userName: String?
            let status: String?
            let errorMessage: String?

            var isRejected: Bool { rejectionReason != nil }

            var rejectionReason: String? {
                let error = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !error.isEmpty { return error }

                let state = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let refusals = ["fail", "failed", "error", "rejected", "exist", "already exists"]
                guard refusals.contains(where: { state.contains($0) }) else { return nil }
                return status
            }
        }
    }

    // MARK: - Endpoints

    /// POST — a trainer or admin marking someone else. The bare controller path.
    struct AdminMarkAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — an end user marking themselves.
    struct EndUserMarkAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance,
             APIConst.updateILTTrainingAttendance].joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// The end-user role code. Anything else — trainer, admin, an unconfigured package —
    /// marks on the admin route.
    static let endUserRole = "eu"

    static func isEndUser(role: String) -> Bool {
        role.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(endUserRole) == .orderedSame
    }
}
