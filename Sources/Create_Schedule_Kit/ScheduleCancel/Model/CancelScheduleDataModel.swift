//
//  CancelScheduleDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for the Cancel Schedule bottom sheet.
//
//   • ILTSchedule/GetNominationCountDetails/{id} → Bool   (are users already nominated?)
//   • ILTSchedule/CancellationSchedule          → empty   (cancel with a reason)
//

import Foundation
import NetworkService

enum CancelScheduleDataModel {

    // MARK: - Endpoints

    /// GET — `true` when users are already nominated/requested for the schedule, which is the
    /// only trigger for the sheet's warning banner.
    struct GetNominationCountDetailsRequest: EndpointModel {
        let scheduleID: Int

        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule,
             APIConst.getNominationCountDetails, "\(scheduleID)"].joined(separator: "/")
        }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// POST — cancel a schedule. Answers with an empty body.
    struct CancellationScheduleRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltSchedule,
             APIConst.cancellationSchedule].joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Payload

    /// Body for `CancellationSchedule`. `scheduleID` is the AES-encrypted numeric id — encrypted
    /// by the view model before it gets here, and passed through untouched.
    struct CancelPayload: Encodable {
        let scheduleID: String
        let reason: String
    }

    // MARK: - Response envelope

    /// `CancellationSchedule` normally answers with an empty body, which surfaces as
    /// `APIError.noData` and is treated as success. Every field here is optional because the
    /// envelope only appears when the endpoint reports a problem on a 200 — the same
    /// `{"statusCode":400,"message":…}` shape the create/update routes use. Decoding it (rather
    /// than `EmptyResponse`, which decodes from *any* JSON) is what keeps a server-side refusal
    /// from being reported as a successful cancellation.
    struct CancelResponse: Decodable {
        let statusCode: Int?
        let message: String?
        let description: String?
    }
}
