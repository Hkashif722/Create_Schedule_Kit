//
//  ScheduleQRCodeViewModel.swift
//  Create_Schedule_Kit
//
//  Generates the schedule's QR and exports it. Learners scan this from their own app to
//  mark themselves present, so what goes into it is the schedule's identity plus the day.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

final class ScheduleQRCodeViewModel: BaseViewModel {

    // MARK: - Dependencies
    let navModel: NavigationViewModel.ScheduleQRCodeNavModel

    // MARK: - Screen state
    @Published private(set) var qrImage: UIImage?
    @Published private(set) var generationFailed = false
    @Published var shareURL: URL?

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.ScheduleQRCodeNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived UI state
extension ScheduleQRCodeViewModel {

    var payload: AttendanceQRDataModel.ScheduleQRPayload {
        .init(
            moduleId: navModel.moduleID,
            scheduleId: navModel.scheduleID,
            courseId: navModel.courseID,
            courseName: navModel.courseName,
            attendanceDate: navModel.attendanceDate.isoDayStartString,
            scheduleCode: navModel.scheduleCode
        )
    }

    var title: String { "Scan Schedule QR" }

    var caption: String { "Learners scan this code to mark their attendance" }

    var subtitle: String {
        let day = Self.mediumDateFormatter.string(from: navModel.attendanceDate)
        return navModel.scheduleCode.isEmpty ? day : "\(navModel.scheduleCode) · \(day)"
    }

    var isShareEnabled: Bool { qrImage != nil }
}

// MARK: - Actions
extension ScheduleQRCodeViewModel {

    func onAppear() {
        guard qrImage == nil, !generationFailed else { return }
        generate()
    }

    func didTapClose() {
        Task { @MainActor [weak self] in self?.router.dismissModal() }
    }

    /// "Download" — hands the file to a share sheet, which is where Save Image lives.
    func didTapDownload() {
        guard let image = qrImage else { return }
        do {
            shareURL = try QRImageExporter.export(
                image,
                scheduleCode: navModel.scheduleCode,
                date: navModel.attendanceDate
            )
        } catch {
            toast = Toast(style: .error, message: "Could not prepare the QR code for sharing.")
            Logger.shared.log(.error, message: "QR export failed: \(error)")
        }
    }

    func didFinishSharing() {
        shareURL = nil
    }

    @MainActor
    private func generate() {
        do {
            qrImage = try QRCodeImageGenerator.image(for: payload)
        } catch {
            // Loud rather than an endless placeholder: the reference leaves its card
            // shimmering forever when the payload cannot be encoded.
            generationFailed = true
            toast = Toast(style: .error, message: "Could not generate the QR code for this schedule.")
            Logger.shared.log(.error, message: "QR generation failed: \(error)")
        }
    }
}

// MARK: - Date formatting
private extension ScheduleQRCodeViewModel {

    static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f
    }()
}
