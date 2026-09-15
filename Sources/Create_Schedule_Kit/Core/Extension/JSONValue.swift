//
//  JSONValue.swift
//  Create_Schedule_Kit
//
//  Shape-agnostic Codable value for API fields the package does not model
//  (e.g. meeting-detail blobs on the schedule details response). Decodes any
//  JSON and re-encodes it verbatim so echo-back payloads never lose data.
//

import Foundation

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value):   try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value):  try container.encode(value)
        case .null:              try container.encodeNil()
        }
    }
}


// MARK: - Meeting-details access

/// The webinar detail fields (`teamsScheduleDetails`, `zoomScheduleDetails`, …) are echoed
/// back to the server untouched, so they are held as raw JSON rather than modelled. Edit
/// mode has to read one value out of them and put one value back, which is all this adds.
extension JSONValue {

    /// The string at `key` — on this object, or on the first object of an array.
    func firstString(forKey key: String) -> String? {
        switch self {
        case .object(let fields):
            if case .string(let value)? = fields[key] { return value }
            return nil
        case .array(let items):
            return items.compactMap { $0.firstString(forKey: key) }.first
        default:
            return nil
        }
    }

    /// A copy with `key` replaced on this object, or on the first object of an array —
    /// every other field, and every other element, is preserved so the server still sees
    /// the row it sent. `nil` when there is no object to write into.
    func settingFirst(_ key: String, to value: JSONValue) -> JSONValue? {
        switch self {
        case .object(var fields):
            fields[key] = value
            return .object(fields)
        case .array(let items):
            guard let index = items.firstIndex(where: { if case .object = $0 { return true } else { return false } }),
                  let updated = items[index].settingFirst(key, to: value)
            else { return nil }
            var copy = items
            copy[index] = updated
            return .array(copy)
        default:
            return nil
        }
    }
}
