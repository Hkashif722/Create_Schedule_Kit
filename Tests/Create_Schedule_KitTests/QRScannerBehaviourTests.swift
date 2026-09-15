//
//  QRScannerBehaviourTests.swift
//  Create_Schedule_KitTests
//
//  The scanner's two rules that need no camera: a QR in front of the lens is one action,
//  and the camera is never *asked* for when the host cannot ask.
//

import AVFoundation
import Foundation
import UIKit
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct QRScannerBehaviourTests {

    init() {
        SwiftUtilityEnvironment.configure(
            SwiftUtilityConfig(
                encryptionDecryptionKey: "preview-key",
                isBlobEnabled: true,
                orgCode: "preview",
                configurableDate: "dd-MM-yyyy",
                baseURL: "",
                lxpOPath: "",
                lxpBlobPath: "",
                lxpBlobPath1: ""
            )
        )
    }

    // MARK: - The single-shot latch

    @Test func theFirstScanIsDeliveredAndTheRestAreSwallowed() {
        var latch = QRScanLatch()

        #expect(latch.accept("first") == "first")
        // The camera keeps delivering the same code many times a second.
        #expect(latch.accept("first") == nil)
        #expect(latch.accept("second") == nil)
        #expect(latch.hasDelivered)
    }

    @Test func reScanReArmsTheLatch() {
        var latch = QRScanLatch()
        _ = latch.accept("first")

        latch.rearm()

        #expect(latch.hasDelivered == false)
        #expect(latch.accept("second") == "second")
    }

    @Test(arguments: [nil, "", "   ", "\n"] as [String?])
    func anUnreadableFrameIsIgnoredWithoutTrippingTheLatch(_ value: String?) {
        var latch = QRScanLatch()

        #expect(latch.accept(value) == nil)
        // Load-bearing: a blank read must not leave the scanner inert until Re-Scan.
        #expect(latch.hasDelivered == false)
        #expect(latch.accept("real") == "real")
    }

    @Test func surroundingWhitespaceIsTrimmedFromTheScannedValue() {
        var latch = QRScanLatch()
        #expect(latch.accept("  {\"UserId\":\"sunny\"}  ") == "{\"UserId\":\"sunny\"}")
    }

    // MARK: - Camera access

    @Test func aHostWithNoUsageDescriptionNeverAsksForTheCamera() {
        // `requestAccess` traps without the Info.plist key, so this must never map to
        // `.notDetermined` — a package cannot declare that key itself.
        for status in [AVAuthorizationStatus.notDetermined, .authorized, .denied, .restricted] {
            #expect(CameraAccess.state(status: status, hasUsageDescription: false) == .unavailable)
        }
    }

    @Test func authorizedStartsTheSession() {
        #expect(CameraAccess.state(status: .authorized, hasUsageDescription: true) == .authorized)
    }

    @Test func notDeterminedAsksOnce() {
        #expect(CameraAccess.state(status: .notDetermined, hasUsageDescription: true) == .notDetermined)
    }

    @Test(arguments: [AVAuthorizationStatus.denied, .restricted])
    func aRefusalOffersSettingsWithoutAskingAgain(_ status: AVAuthorizationStatus) {
        #expect(CameraAccess.state(status: status, hasUsageDescription: true) == .denied)
    }

    // MARK: - What the scanner posts

    @MainActor
    private func viewModel(date: Date = Date()) -> AttendanceQRScannerViewModel {
        AttendanceQRScannerViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                scheduleID: 4307, courseID: 59258, moduleID: 46404,
                courseName: "ELGI Live Class",
                attendanceDate: date,
                onMarked: {}
            )
        )
    }

    /// `UserId` and `UserEmail` arrive encrypted; `Id` and `UserName` are plain.
    private func payload() throws -> AttendanceQRDataModel.ProfileQRPayload {
        try #require(AttendanceQRDataModel.ProfileQRPayload.decode(
            #"{"Id":"11998","UserId":"INISu97c5utzCRj1Jkpsiw==","UserName":"Sunny Rasal","UserEmail":"ENC=="}"#
        ))
    }

    @MainActor
    @Test func theMarkItemTakesItsIdsFromTheScheduleAndItsUserFromTheScan() throws {
        let day = Date(timeIntervalSince1970: 1_788_000_000)
        let item = viewModel(date: day).markItem(for: try payload())

        // Straight off the QR, still encrypted — the endpoint matches the nomination on it.
        #expect(item.eUserID == "INISu97c5utzCRj1Jkpsiw==")
        #expect(item.scheduleId == 4307)
        #expect(item.courseId == 59258)
        #expect(item.moduleId == 46404)
        #expect(item.courseTitle == "ELGI Live Class")
        #expect(item.attendanceDate == day.isoDayStartString)
        // Always Attended: a scan means the person is in the room.
        #expect(item.attendanceStatus == AttendanceDataModel.StatusCode.attended)
        #expect(item.isPresent == 1)
    }

    /// The host supplies the *scanning* user's number. It is unset in tests, and an unset
    /// number must not stop a scan — the key goes out empty rather than as the encryption
    /// of an empty string.
    @MainActor
    @Test func anUnsuppliedMobileNumberStillMarks() throws {
        let item = viewModel().markItem(for: try payload())
        #expect(item.mobileNumber == "")
        #expect(item.isPresent == 1)
    }

    @MainActor
    @Test func anUnconfiguredPackageMarksOnTheAdminRoute() {
        // No host role configured, so not an end user.
        let request = viewModel().markRequest()
        #expect(request.path == "/api/v1/ILTTrainingAttendance")
    }

    @MainActor
    @Test func theScannerOpensWithNoCameraDecisionYet() {
        let model = viewModel()
        #expect(model.access == .notDetermined)
        #expect(model.isPreviewVisible == false)
        #expect(model.offersSettings == false)
    }
}

// MARK: - Reading a QR out of a gallery image

@Suite struct QRImageDecoderTests {

    /// Renders a QR, then reads it back — the round trip the "Upload from Gallery" path does
    /// when someone picks a screenshot of their own code.
    @Test func aGeneratedCodeIsReadBackFromItsImage() throws {
        let payload = AttendanceQRDataModel.ScheduleQRPayload(
            moduleId: 46404, scheduleId: 4307, courseId: 59258,
            courseName: "ELGI Live Class", attendanceDate: "2026-09-09T00:00:00",
            scheduleCode: "SC9202"
        )
        let image = try QRCodeImageGenerator.image(for: payload)

        let decoded = try QRImageDecoder.decode(image)
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(decoded.utf8)) as? [String: Any]
        )
        #expect(object["ScheduleCode"] as? String == "SC9202")
        #expect(object["ScheduleId"] as? Int == 4307)
    }

    @Test func aProfileQRSurvivesTheRoundTripAndStillDecodes() throws {
        // The payload the trainer actually scans, as a picked image.
        struct Profile: Encodable {
            let Id = "11998"
            let UserId = "sunny"
            let UserName = "Sunny Rasal"
            let UserEmail = "ENC_EMAIL=="
        }
        let image = try QRCodeImageGenerator.image(for: Profile())

        let payload = try #require(
            AttendanceQRDataModel.ProfileQRPayload.decode(try QRImageDecoder.decode(image))
        )
        #expect(payload.userId == "sunny")
        #expect(payload.displayName == "Sunny Rasal")
    }

    @Test func aPictureWithNoCodeInItFailsAsNoCodeFound() throws {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        }

        #expect(throws: QRImageDecoder.Failure.noCodeFound) {
            _ = try QRImageDecoder.decode(blank)
        }
    }

    @Test func aMissingFileFailsAsUnreadableRatherThanCrashing() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-such-image-\(UUID().uuidString).png")

        #expect(throws: QRImageDecoder.Failure.imageUnreadable) {
            _ = try QRImageDecoder.decode(imageAt: url)
        }
    }

    @Test func anImageOnDiskIsDecodedFromItsURL() throws {
        // The picker hands over a temp file, not a UIImage.
        let payload = AttendanceQRDataModel.ScheduleQRPayload(
            moduleId: 1, scheduleId: 2, courseId: 3,
            courseName: "Course", attendanceDate: "2026-09-09T00:00:00", scheduleCode: "SC1"
        )
        let image = try QRCodeImageGenerator.image(for: payload)
        let url = try QRImageExporter.export(image, scheduleCode: "SC1", date: Date())
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = try QRImageDecoder.decode(imageAt: url)
        #expect(decoded.contains("\"ScheduleCode\":\"SC1\""))
    }
}
