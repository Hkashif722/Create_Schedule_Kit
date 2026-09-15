//
//  CameraAccess.swift
//  Create_Schedule_Kit
//
//  Whether the scanner may open the camera, and why not when it may not.
//
//  The mapping is pure so it can be tested without a device. The important case is
//  `.unavailable`: `AVCaptureDevice.requestAccess` **crashes** when the host's Info.plist
//  carries no `NSCameraUsageDescription`, and a package cannot declare that key itself — so
//  the key is checked before anything is requested, and a misconfigured host gets a
//  degraded screen instead of a crash.
//

import AVFoundation
import Foundation

enum CameraAccess {

    enum State: Equatable {
        /// Ready to configure and start.
        case authorized
        /// Never asked. Safe to request, exactly once.
        case notDetermined
        /// Refused, or restricted by policy. Offer Settings; never re-request.
        case denied
        /// The host cannot ask at all — no usage description in its Info.plist.
        case unavailable
    }

    static let usageDescriptionKey = "NSCameraUsageDescription"

    /// Pure mapping, so every branch is reachable from a test.
    static func state(
        status: AVAuthorizationStatus,
        hasUsageDescription: Bool
    ) -> State {
        guard hasUsageDescription else { return .unavailable }
        switch status {
        case .authorized:            return .authorized
        case .notDetermined:         return .notDetermined
        case .denied, .restricted:   return .denied
        @unknown default:            return .denied
        }
    }

    static var hasUsageDescription: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: usageDescriptionKey) as? String
        else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var current: State {
        state(
            status: AVCaptureDevice.authorizationStatus(for: .video),
            hasUsageDescription: hasUsageDescription
        )
    }

    /// Only ever called for `.notDetermined` — requesting twice is a no-op that looks like a
    /// silent refusal.
    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
