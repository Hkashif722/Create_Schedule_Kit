//
//  AttendanceView.swift
//  Create_Schedule_Kit
//
//  "Update Attendance" — the schedule's read-only details, the attendance date, and the ways
//  to act on it. Marking itself happens on the screens this one opens: Bulk Mark for a
//  status against many people, Scan QR for one at a time, and Attendees to read the list.
//
//  Scan QR and Download appear only where the host licensed QR attendance.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct AttendanceView: View {

    @StateObject private var viewModel: AttendanceViewModel
    private let router: AnyRouter

    init(router: AnyRouter, navModel: NavigationViewModel.AttendanceNavModel) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: AttendanceViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                courseAndScheduleCard
                attendanceDetailsCard
                markAttendanceCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Update Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Cards
private extension AttendanceView {

    var courseAndScheduleCard: some View {
        AttendanceSectionCard(title: "COURSE & SCHEDULE") {
            CSTextField(title: "Course Name", placeholder: "-",
                        text: .constant(viewModel.navModel.courseName), isReadOnly: true)
            CSTextField(title: "Module", placeholder: "-",
                        text: .constant(viewModel.navModel.moduleName), isReadOnly: true)
            CSTextField(title: "Schedule Code", placeholder: "-",
                        text: .constant(viewModel.navModel.scheduleCode), isReadOnly: true)

            Divider()

            infoRow(label: "Dates", value: viewModel.scheduleDateRangeText)
        }
    }

    var attendanceDetailsCard: some View {
        AttendanceSectionCard(title: "ATTENDANCE DETAILS") {
            CSRequiredDateField(
                router: router,
                title: "Attendance for the Date",
                placeHolder: "Select date",
                minimumDate: viewModel.datePickerMinimum,
                maximumDate: viewModel.datePickerMaximum,
                onDateSelected: { viewModel.didSelectDate($0) }
            )
        }
    }

    /// All three ways of marking are always available — scanning a learner's QR and handing
    /// out the schedule's QR are part of the trainer's job, not a licensed extra.
    var markAttendanceCard: some View {
        AttendanceSectionCard(
            title: "MARK ATTENDANCE",
            accessory: {
                Button { viewModel.didTapAttendees() } label: {
                    HStack(spacing: 4) {
                        Text("Attendees")
                            .font(.system(size: 14, weight: .bold))
                        if !viewModel.attendeesCountText.isEmpty {
                            Text("(\(viewModel.attendeesCountText))")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(ColorUtility.primaryColor)
                }
                .buttonStyle(.plain)
            },
            content: {
                HStack(spacing: 10) {
                    AttendanceActionTileView(
                        title: "Scan QR",
                        systemImage: "qrcode.viewfinder",
                        action: { viewModel.didTapScanQR() }
                    )

                    AttendanceActionTileView(
                        title: "Bulk mark",
                        systemImage: "checkmark.circle",
                        action: { viewModel.didTapBulkMark() }
                    )

                    AttendanceActionTileView(
                        title: "Download",
                        systemImage: "arrow.down.circle",
                        action: { viewModel.didTapDownload() }
                    )
                }
            }
        )
    }

    func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    AttendanceView(
        router: router,
        navModel: .init(
            scheduleID: 3787, courseID: 56288, moduleID: 42182,
            courseName: "ELGI Live Class", moduleName: "20651_ELGI Live Class",
            scheduleCode: "SC9202", dateRangeText: "Sep 09, 2026 – Sep 09, 2026"
        )
    )
}
