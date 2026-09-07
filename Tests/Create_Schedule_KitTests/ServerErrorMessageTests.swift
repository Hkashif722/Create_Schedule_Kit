//
//  ServerErrorMessageTests.swift
//  Create_Schedule_KitTests
//
//  Bug: creating a schedule against an already-booked training place showed a wrong
//  validation message instead of the server's reason.
//
//  The reason can arrive two ways, and each was dropping it:
//   • a refused envelope (statusCode != 200), whose text sits under `message` on some
//     routes and `description` on others — only `message` was read;
//   • a thrown `APIError.customError`, whose message was replaced with "Encoding failed"
//     during conversion to the UI error type.
//

import Testing
import Foundation
import NetworkService
import SwiftUIUtilities
@testable import Create_Schedule_Kit

@Suite struct ServerErrorMessageTests {

    private static let booked = "Training place is already booked for the selected dates."

    private func envelope(message: String?, description: String?, statusCode: Int = 400) throws
        -> CreateScheduleWizardDataModel.CreateScheduleResponse {
        let object: [String: Any] = [
            "statusCode": statusCode,
            "message": message ?? NSNull(),
            "description": description ?? NSNull()
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(
            CreateScheduleWizardDataModel.CreateScheduleResponse.self,
            from: data
        )
    }

    // MARK: - Refused envelope

    @Test func aReasonUnderMessageIsUsed() throws {
        #expect(try envelope(message: Self.booked, description: nil).serverMessage == Self.booked)
    }

    @Test func aReasonUnderDescriptionIsUsed() throws {
        // The shape that produced the bug: `message` null, the real text in `description`.
        #expect(try envelope(message: nil, description: Self.booked).serverMessage == Self.booked)
    }

    @Test func messageWinsWhenBothCarryText() throws {
        #expect(try envelope(message: Self.booked, description: "Bad Request").serverMessage == Self.booked)
    }

    @Test func surroundingWhitespaceIsTrimmed() throws {
        #expect(try envelope(message: "  \(Self.booked)\n", description: nil).serverMessage == Self.booked)
    }

    @Test(arguments: [nil, "", "   "] as [String?])
    func anEnvelopeWithNoTextFallsBackToTheCaller(_ value: String?) throws {
        // `nil` lets the call site supply "Could not create schedule."
        #expect(try envelope(message: value, description: value).serverMessage == nil)
    }

    @Test func theHappyPathDescriptionIsNeverShownAsAnError() throws {
        // These routes answer "success" in `description`; a failure branch must not echo it.
        #expect(try envelope(message: nil, description: "success").serverMessage == nil)
        #expect(try envelope(message: nil, description: "Success").serverMessage == nil)
    }

    @Test func aRealReasonStillWinsOverTheHappyPathWord() throws {
        #expect(try envelope(message: Self.booked, description: "success").serverMessage == Self.booked)
    }

    // MARK: - Thrown error conversion

    @Test func aCustomErrorKeepsTheServersMessage() throws {
        let converted = NetworkService.APIError.customError(message: Self.booked).toUIError()

        guard case .customError(let message) = converted else {
            Issue.record("expected a customError, got \(converted)")
            return
        }
        #expect(message == Self.booked)
    }

    @Test func aValidationFailureKeepsItsMessage() throws {
        let converted = NetworkService.APIError.validationFailed(Self.booked).toUIError()

        guard case .customError(let message) = converted else {
            Issue.record("expected a customError, got \(converted)")
            return
        }
        #expect(message == Self.booked)
    }

    @Test func aServerErrorCarriesItsCodeAndMessageThrough() throws {
        let converted = NetworkService.APIError.serverError(statusCode: 409, message: Self.booked).toUIError()

        guard case .serverError(let statusCode, let message) = converted else {
            Issue.record("expected a serverError, got \(converted)")
            return
        }
        #expect(statusCode == 409)
        #expect(message == Self.booked)
    }
}
