//
//  AttendanceQRScannerViewModel.swift
//  Create_Schedule_Kit
//
//  Scans a learner's profile QR and marks them present.
//
//  A scan is a write, so it is confirmed before it happens: decode → show who was scanned →
//  Mark or Re-Scan. Camera access is pre-flighted rather than requested blindly, because a
//  host with no camera usage description would crash on the request.
//

import AVFoundation
import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class AttendanceQRScannerViewModel: BaseViewModel {

    typealias QR = AttendanceQRDataModel

    // MARK: - Dependencies
    let navModel: NavigationViewModel.AttendanceQRScannerNavModel
    let captureSession = QRCaptureSession()

    // MARK: - Screen state
    @Published private(set) var access: CameraAccess.State = .notDetermined
    @Published private(set) var isMarking = false

    private var hasStarted = false

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.AttendanceQRScannerNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived UI state
extension AttendanceQRScannerViewModel {

    var isPreviewVisible: Bool { access == .authorized }

    var caption: String { "Point the camera at the learner's QR code" }

    var accessMessage: String {
        switch access {
        case .denied:
            return "Camera access is off for this app. Turn it on in Settings to scan a QR code."
        case .unavailable:
            return "Camera is not available in this app."
        case .authorized, .notDetermined:
            return ""
        }
    }

    /// There is nothing for the user to change when the host itself cannot ask.
    var offersSettings: Bool { access == .denied }

    var attendanceDateText: String {
        Self.mediumDateFormatter.string(from: navModel.attendanceDate)
    }
}

// MARK: - Lifecycle
extension AttendanceQRScannerViewModel {

    func onAppear() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { [weak self] in await self?.prepareCamera() }
    }

    func onDisappear() {
        captureSession.stop()
    }

    func didTapClose() {
        captureSession.stop()
        Task { @MainActor [weak self] in self?.router.dismissScreen() }
    }

    /// "Upload from Gallery" — for a QR that was screenshotted or sent rather than held up
    /// to the camera. `PHPickerViewController` runs out of process, so this needs no photo
    /// library permission and no Info.plist key.
    func didTapUploadFromGallery() {
        // Nothing should keep scanning behind the picker.
        captureSession.stop()

        let picker = NavigationViewModel.DocumentPickerModel(
            allowedContentTypes: [.image],
            fileURLProvider: { [weak self] url in
                Task { @MainActor in self?.handlePickedImage(url) }
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.showPhotoPickerView(picker))
        )
    }

    @MainActor
    private func handlePickedImage(_ url: URL?) {
        guard let url else {
            // Cancelled, or the picker could not hand over the image.
            resumeScanningIfPossible()
            return
        }
        do {
            handleScan(try QRImageDecoder.decode(imageAt: url))
        } catch {
            showRetryableError("No QR code found in that image. Pick another, or scan it directly.")
        }
    }

    /// The camera keeps running behind the popups, so it only needs restarting after a
    /// detour that stopped it — the gallery picker.
    @MainActor
    private func resumeScanningIfPossible() {
        guard access == .authorized else { return }
        rescan()
    }

    func didTapOpenSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func prepareCamera() async {
        // Never request without the key: `requestAccess` traps when it is absent.
        switch CameraAccess.current {
        case .authorized:
            access = .authorized
            startScanning()

        case .notDetermined:
            let granted = await CameraAccess.request()
            access = granted ? .authorized : .denied
            if granted { startScanning() }

        case .denied:
            access = .denied

        case .unavailable:
            access = .unavailable
            Logger.shared.log(
                .error,
                message: "Camera unavailable: the host app declares no \(CameraAccess.usageDescriptionKey)."
            )
        }
    }

    @MainActor
    private func startScanning() {
        do {
            try captureSession.configureIfNeeded()
        } catch {
            access = .unavailable
            Logger.shared.log(.error, message: "QR capture session failed: \(error)")
            return
        }
        captureSession.start { [weak self] scanned in
            self?.handleScan(scanned)
        }
    }

    /// Re-Scan.
    @MainActor
    private func rescan() {
        captureSession.rearm { [weak self] scanned in
            self?.handleScan(scanned)
        }
    }
}

// MARK: - Scanning
extension AttendanceQRScannerViewModel {

    @MainActor
    private func handleScan(_ scanned: String) {
        guard let payload = QR.ProfileQRPayload.decode(scanned) else {
            showRetryableError(
                "That is not a learner's QR code. Ask them to open the QR from their profile."
            )
            return
        }
        confirmMark(payload)
    }

    /// The email is stored encrypted and decrypted for this popup only — it is never posted.
    @MainActor
    private func confirmMark(_ payload: QR.ProfileQRPayload) {
        let decryptedEmail = payload.userEmail.map {
            let decrypted = EncryptDecryptUtility.shared.newDecryptString(responseStr: $0)
            return decrypted.isEmpty ? $0 : decrypted
        }

        let model = CustomAlertPopupModel(
            title: "Mark Attendance",
            alertType: .none,
            content: {
                ProfileQRConfirmContent(
                    name: payload.displayName,
                    email: decryptedEmail,
                    attendanceDate: self.attendanceDateText
                )
            },
            primaryButtonTitle: "Mark",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
                Task { await self?.mark(payload) }
            },
            secondaryButtonTitle: "Re-Scan",
            secondaryAction: { [weak self] in
                self?.router.dismissModal()
                self?.rescan()
            }
        )
        present(model)
    }

    @MainActor
    private func showRetryableError(_ message: String) {
        let model = CustomAlertPopupModel(
            title: "Scan",
            alertType: .warning,
            content: {
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding()
            },
            primaryButtonTitle: "Re-Scan",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
                self?.rescan()
            }
        )
        present(model)
    }

    @MainActor
    private func present(_ model: CustomAlertPopupModel) {
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.customAlertPopupView(model))
        )
    }
}

// MARK: - API
extension AttendanceQRScannerViewModel {

    func markRequest() -> any EndpointModel {
        QR.isEndUser(role: CreateScheduleKitAPIManager.shared.getUserRole)
            ? QR.EndUserMarkAttendanceRequest()
            : QR.AdminMarkAttendanceRequest()
    }

    func markItem(for payload: QR.ProfileQRPayload) -> QR.MarkFromProfileQRItem {
        QR.MarkFromProfileQRItem(
            eUserID: payload.userId,
            moduleId: navModel.moduleID,
            scheduleId: navModel.scheduleID,
            courseId: navModel.courseID,
            courseTitle: navModel.courseName,
            attendanceDate: navModel.attendanceDate.isoDayStartString,
            // The host stores this in the clear; the endpoint wants it encrypted.
            mobileNumber: CreateScheduleKitAPIManager.shared.getUserMobileNumber.encryptedForWire
        )
    }

    @MainActor
    private func mark(_ payload: QR.ProfileQRPayload) async {
        guard !isMarking else { return }
        isMarking = true
        defer { isMarking = false }

        loadingState = .loading(title: "Marking attendance", message: "Please wait.")
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: QR.MarkAttendanceResponse.self,
                model: markRequest(),
                payload: [markItem(for: payload)]
            )
            loadingState = .none

            guard response.isSuccess else {
                showRetryableError(response.failureMessage ?? "Could not mark attendance. Please try again.")
                return
            }
            
            navModel.onMarked()
            
            toast = Toast(
                style: .success,
                message: response.successMessage ?? "\(payload.displayName) marked present."
            )
            rescan()
        } catch let error as APIError {
            loadingState = .none
            showRetryableError(error.toUIError().localizedDescription)
        } catch {
            loadingState = .none
            showRetryableError(error.localizedDescription)
        }
    }
}

// MARK: - Date formatting
private extension AttendanceQRScannerViewModel {

    static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f
    }()
}
