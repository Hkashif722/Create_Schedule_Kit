//
//  PlainTextAPIClient.swift
//  Create_Schedule_Kit
//
//  A minimal GET client for endpoints that return a *plain-text* body (e.g. a bare `No`
//  / `Yes`) rather than valid JSON. `ApiService` always runs responses through
//  `JSONDecoder`, which rejects an unquoted string, so those endpoints must bypass it.
//
//  It reuses the same base URL + `Authorization: Bearer` scheme as `ApiService`
//  (see NetworkService `AuthenticationMiddleware`).
//

import Foundation
import NetworkService

enum PlainTextAPIClient {

    /// Performs a GET for `model` and returns the response body as a trimmed string.
    /// Surrounding quotes are stripped too, so it works whether the server returns
    /// `No` or `"No"`.
    static func get(_ model: EndpointModel) async throws -> String {
        guard let url = URL(string: model.baseURL + model.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = CreateScheduleKitAPIManager.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        model.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }

        let raw = String(data: data, encoding: .utf8) ?? ""
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
