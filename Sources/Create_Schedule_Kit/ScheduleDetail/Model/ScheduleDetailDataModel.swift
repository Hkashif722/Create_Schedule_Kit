//
//  ScheduleDetailDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the Schedule Details screen's nominees section.
//
//   • ILTTrainingAttendance/GetUsersForAttendance      → [Nominee]  (paginated)
//   • ILTTrainingAttendance/GetUsersCountForAttendance → Int        (count, parallel)
//   • TrainingNomination/DeleteUserNomination          → empty body (remove a nominee)
//

import Foundation
import NetworkService

enum ScheduleDetailDataModel {

    // MARK: - Endpoints

    /// POST — nominated/attending users for a schedule. Returns a bare `[Nominee]`.
    struct GetUsersForAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersForAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — count of nominees for a schedule. Returns a bare `Int`.
    struct GetUsersCountForAttendanceRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltTrainingAttendance, APIConst.getUsersCountForAttendance]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// POST — remove a nominated user from the schedule. Returns an empty body.
    struct DeleteUserNominationRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.trainingNomination, APIConst.deleteUserNomination]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Payload

    /// Body for `DeleteUserNomination`. `UserIdEncrypted` is the nominee row's numeric id,
    /// AES-encrypted by the view model — passed through untouched, never decoded.
    struct DeleteNominationPayload: Encodable {
        let scheduleID: Int
        let courseId: Int
        let moduleId: Int
        let userIdEncrypted: String

        enum CodingKeys: String, CodingKey {
            case scheduleID, courseId, moduleId
            case userIdEncrypted = "UserIdEncrypted"
        }
    }

    /// Shared body for the attendance list + count. `Type` keeps the server's "Attandance" spelling.
    struct AttendancePayload: Encodable {
        let scheduleID: Int
        let courseId: Int
        let moduleId: Int
        let page: Int
        let pageSize: Int
        let searchText: String?
        let search1: String?
        let searchText1: String?
        let type: String

        enum CodingKeys: String, CodingKey {
            case scheduleID, courseId, moduleId, page, pageSize, searchText, search1, searchText1
            case type = "Type"
        }
    }

    // MARK: - Domain model

    struct Nominee: Decodable, Identifiable, Equatable {
        let id: Int
        let userId: String?
        let userName: String?
        let emailId: String?
        let mobileNumber: String?
        let status: String?
        let trainingRequestStatus: String?
        let overAllStatus: String?
        let isPresent: Bool?

        var displayName: String { userName ?? userId ?? "User \(id)" }
        var isConfirmed: Bool { (status ?? "").lowercased() == "true" }
        var statusText: String {
            if isConfirmed { return "Confirmed" }
            return trainingRequestStatus ?? "Pending"
        }
    }

    /// One row of the TRAINERS section. A schedule can carry several trainers, so the
    /// screen lists `trainerList` from `GetScheduleDetailsByID` rather than the single
    /// trainer name the schedule list row carries.
    struct TrainerDisplay: Identifiable, Equatable {
        let id: String
        let name: String
        /// Normalized type ("Internal"/"External"/"Consultant"); nil when the server
        /// sends none — the badge is then hidden rather than guessed.
        let type: String?
    }
}

extension ScheduleDetailDataModel.TrainerDisplay {

    /// Builds the TRAINERS rows from the fetched schedule, falling back to the single
    /// trainer on the tapped list row while the details call is still in flight (or for
    /// older schedules that carry no `trainerList`).
    static func list(
        from trainerList: [EditScheduleDataModel.TrainerItem]?,
        scheduleTrainerType: String?,
        fallbackName: String?,
        fallbackType: String?
    ) -> [ScheduleDetailDataModel.TrainerDisplay] {
        let rows = (trainerList ?? []).enumerated().compactMap { index, item -> ScheduleDetailDataModel.TrainerDisplay? in
            guard let raw = firstNonEmpty(item.nameUserId, item.academyTrainerName) else { return nil }
            // The card carries a type badge of its own, so a type the server appended to
            // `nameUserId` is dropped rather than shown twice (and truncating the name).
            let name = TrainerType.strippingTypeSuffix(from: raw)
            guard !name.isEmpty else { return nil }
            return ScheduleDetailDataModel.TrainerDisplay(
                // `academyTrainerID` can repeat across rows, so the index keeps ids unique.
                id: "\(item.academyTrainerID.map(String.init) ?? "row")-\(index)",
                name: name,
                type: resolvedType(suffixedName: raw, itemType: item.trainerType, scheduleType: scheduleTrainerType)
            )
        }
        guard rows.isEmpty else { return rows }

        guard let fallback = firstNonEmpty(fallbackName), fallback != "-" else { return [] }
        let name = TrainerType.strippingTypeSuffix(from: fallback)
        guard !name.isEmpty else { return [] }
        return [
            ScheduleDetailDataModel.TrainerDisplay(
                id: "schedule-trainer",
                name: name,
                type: resolvedType(suffixedName: fallback, itemType: fallbackType, scheduleType: nil)
            )
        ]
    }

    /// The badge for one trainer. A schedule can mix Internal, External and Consultant
    /// trainers, but `GetScheduleDetailsByID` carries only one `trainerType` for the whole
    /// schedule — using it for every row badged all three trainers of a mixed schedule with
    /// whichever type the organiser happened to pick last. The type the server appends to the
    /// trainer's own `nameUserId` ("kashif-kashif (Internal)") is per-trainer, so it wins;
    /// the row's `trainerType` and then the schedule's stand in when the name carries none.
    private static func resolvedType(suffixedName: String, itemType: String?, scheduleType: String?) -> String? {
        TrainerType.typeSuffix(in: suffixedName)
            ?? TrainerType.normalized(itemType)
            ?? TrainerType.normalized(scheduleType)
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
