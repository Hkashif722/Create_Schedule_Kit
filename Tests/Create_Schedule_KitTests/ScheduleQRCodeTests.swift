//
//  ScheduleQRCodeTests.swift
//  Create_Schedule_KitTests
//
//  The QR the trainer hands out: what goes into it, that it renders, and how "Download"
//  names the file.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleQRCodeTests {

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

    private static let day = Date(timeIntervalSince1970: 1_788_000_000)

    @MainActor
    private func viewModel(
        courseName: String = "ELGI Live Class",
        scheduleCode: String = "SC9202"
    ) -> ScheduleQRCodeViewModel {
        ScheduleQRCodeViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                scheduleID: 4307, courseID: 59258, moduleID: 46404,
                courseName: courseName, scheduleCode: scheduleCode,
                attendanceDate: Self.day
            )
        )
    }

    // MARK: - What the QR carries

    @MainActor
    @Test func theQRCarriesTheScheduleAndTheDay() {
        let payload = viewModel().payload

        #expect(payload.scheduleId == 4307)
        #expect(payload.courseId == 59258)
        #expect(payload.moduleId == 46404)
        #expect(payload.courseName == "ELGI Live Class")
        #expect(payload.scheduleCode == "SC9202")
        #expect(payload.attendanceDate == Self.day.isoDayStartString)
        #expect(!payload.attendanceDate.hasSuffix("Z"))
    }

    // MARK: - Generation

    @MainActor
    @Test func aTypicalPayloadRenders() throws {
        let image = try QRCodeImageGenerator.image(for: viewModel().payload)
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @MainActor
    @Test func aNonASCIICourseNameStillRenders() throws {
        // The reference encodes as `.ascii`, so this case silently produced no QR at all and
        // left the card on its loading placeholder forever.
        let payload = viewModel(courseName: "Sécurité ₹ Niveau 1 — 日本語").payload
        let data = try QRCodeImageGenerator.encode(payload)
        let image = try QRCodeImageGenerator.image(for: payload)

        #expect(!data.isEmpty)
        #expect(image.size.width > 0)
    }

    @Test func anOversizedPayloadFailsLoudlyRatherThanRenderingNothing() {
        // Past what a QR can hold, so the caller can say so instead of showing a blank card.
        struct Oversized: Encodable { let blob: String }
        let payload = Oversized(blob: String(repeating: "A", count: 8_000))

        #expect(throws: QRCodeImageGenerator.Failure.payloadTooLarge) {
            _ = try QRCodeImageGenerator.image(for: payload)
        }
    }

    // MARK: - Export

    @Test func theFileNameNamesTheScheduleAndTheDay() {
        let name = QRImageExporter.fileName(scheduleCode: "SC9202", date: Self.day)
        #expect(name.hasPrefix("ScheduleQR_SC9202_"))
        #expect(name.hasSuffix(".png"))
    }

    @Test func aScheduleCodeWithAwkwardCharactersStillMakesAValidFileName() {
        let name = QRImageExporter.fileName(scheduleCode: "SC 92/02", date: Self.day)
        #expect(!name.contains("/"))
        #expect(!name.contains(" "))
        #expect(name.hasSuffix(".png"))
    }

    @Test func aMissingScheduleCodeStillNamesTheDay() {
        let name = QRImageExporter.fileName(scheduleCode: "   ", date: Self.day)
        #expect(name.hasPrefix("ScheduleQR_"))
        #expect(name.hasSuffix(".png"))
    }

    @MainActor
    @Test func exportingWritesAFileThatExists() throws {
        let image = try QRCodeImageGenerator.image(for: viewModel().payload)
        let url = try QRImageExporter.export(image, scheduleCode: "SC9202", date: Self.day)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.pathExtension == "png")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Screen state

    @MainActor
    @Test func downloadIsUnavailableUntilTheCodeHasRendered() {
        let model = viewModel()
        #expect(model.isShareEnabled == false)
        #expect(model.shareURL == nil)

        model.onAppear()

        #expect(model.isShareEnabled)
        #expect(model.generationFailed == false)
    }

    @MainActor
    @Test func downloadProducesAFileForTheShareSheet() {
        let model = viewModel()
        model.onAppear()

        model.didTapDownload()

        #expect(model.shareURL != nil)
        model.didFinishSharing()
        #expect(model.shareURL == nil)
    }
}
