//
//  File.swift
//  OJT_Package
//
//  Created by Kashif Hussain on 08/04/26.
//

import NetworkService
import SwiftUIUtilities

extension NetworkService.APIError {
    func toUIError() -> APIErrorUtils {
        switch self {
            
        // MARK: - Direct mappings
            
        case .invalidResponse:
            return .invalidResponse
            
        case .noData:
            return .noData
            
        case .unauthorized:
            return .unauthorized
            
        case .unknownError:
            return .unknownError
            
        case .decodingError(let error):
            return .decodingError(error)
            
        case .networkError(let error):
            return .networkError(error)
            
        case .serverError(let code, let message):
            return .serverError(statusCode: code, message: message)
            
            
        // MARK: - Request / system
            
        case .invalidURL:
            return .customError(message: "Invalid URL")
            
        case .validationFailed(let message):
            return .customError(message: message)
            
            
        // MARK: - HTTP mappings
            
        case .badRequest(let dict, let rawJSON):
            return .badRequest(dict, rawJSON: rawJSON)
            
        case .resourceGone(let dict, let rawJSON):
            return .resourceGone(dict, rawJSON: rawJSON)
            
        case .unprocessableEntity(let dict, let rawJSON):
            return .badRequest(dict, rawJSON: rawJSON)
            
        case .tooManyRequests:
            return .rateLimited(
                retryAfter: nil,
                message: "Too many requests"
            )
            
        case .rateLimitExceeded(let retryAfter):
            return .rateLimited(
                retryAfter: retryAfter,
                message: "Rate limit exceeded"
            )
            
            
        // MARK: - Missing equivalents
            
        case .forbidden:
            return .customError(message: "Access forbidden")
            
        case .notFound:
            return .customError(message: "Resource not found")
        case .encodingFailed:
            return .customError(message: "Encoding failed")
       
        case .customError(message: let message):
            return .customError(message: "Encoding failed")
       
        }
    }
}
