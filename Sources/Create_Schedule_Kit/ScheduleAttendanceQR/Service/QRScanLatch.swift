//
//  QRScanLatch.swift
//  Create_Schedule_Kit
//
//  A camera delivers the same QR many times a second. The scanner acts on the first frame
//  and ignores the rest until it is deliberately re-armed, so one QR in front of the lens
//  cannot mark the same person twice.
//
//  Pure, so the rule is testable without a camera.
//

import Foundation

struct QRScanLatch {

    private(set) var hasDelivered = false

    /// The value to act on, or `nil` to ignore this frame.
    ///
    /// An unreadable or empty frame does **not** trip the latch — otherwise a blank read
    /// would leave the scanner inert until the user tapped Re-Scan.
    mutating func accept(_ scanned: String?) -> String? {
        guard !hasDelivered else { return nil }
        guard let value = scanned?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        hasDelivered = true
        return value
    }

    /// Re-Scan.
    mutating func rearm() {
        hasDelivered = false
    }
}
