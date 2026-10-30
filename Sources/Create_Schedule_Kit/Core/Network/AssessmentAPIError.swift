//
//  AssessmentAPIError.swift
//  Create_Schedule_Kit
//
//  The quiz and question-package routes (Assessment API) answer every handled failure with
//  `{ message, description, statusCode }`: `message` is a machine code ("Duplicate",
//  "DependancyExist", "AttemptExist"...), `description` is copy written for the user.
//
//  NetworkService keeps the whole body only for 400. For 403/404/409 it throws
//  `serverError(statusCode:message:)` carrying `message` alone, so the code survives and the
//  description does not. Screens therefore branch on (status, code) and supply their own copy
//  where the description is gone.
//

import Foundation
import NetworkService

struct AssessmentAPIError: Equatable {

    let statusCode: Int?
    /// The machine code from `message`.
    let code: String?
    /// The display text from `description`. Only present on 400s.
    let description: String?

    init(statusCode: Int?, code: String?, description: String?) {
        self.statusCode = statusCode
        self.code = code
        self.description = description
    }

    /// Nil for anything that isn't an HTTP failure (no network, decoding...). Those go through
    /// `handleAPIError` like every other screen.
    init?(_ error: Error) {
        guard let apiError = error as? APIError else { return nil }
        switch apiError {
        case .badRequest(let dict, _):
            self.init(statusCode: 400,
                      code: dict["message"] as? String,
                      description: Self.trimmed(dict["description"] as? String))
        case .serverError(let status, let message):
            self.init(statusCode: status, code: Self.trimmed(message), description: nil)
        case .forbidden:
            self.init(statusCode: 403, code: nil, description: nil)
        case .notFound:
            self.init(statusCode: 404, code: nil, description: nil)
        default:
            return nil
        }
    }

    func isCode(_ value: String) -> Bool {
        code?.caseInsensitiveCompare(value) == .orderedSame
    }

    /// A 400 with `InternalServerError` is the server's own crash, not a validation message.
    var isInternalServerError: Bool { isCode("InternalServerError") }

    /// The server's description when it reached us, otherwise `fallback`.
    func message(fallback: String) -> String {
        guard !isInternalServerError, let description, !description.isEmpty else { return fallback }
        return description
    }

    private static func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

extension AssessmentAPIError {
    static let genericMessage = "Something went wrong. Please try again."
}
