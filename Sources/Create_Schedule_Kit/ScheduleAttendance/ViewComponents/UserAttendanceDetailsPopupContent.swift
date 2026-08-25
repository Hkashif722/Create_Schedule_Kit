//
//  UserAttendanceDetailsPopupContent.swift
//  Create_Schedule_Kit
//
//  Body of the "User Attendance Details" popup, opened by the eye button on an attendance row:
//  a two-column Date / Attendance Status table with an "N total" footer.
//
//  Presentational only — it is handed to `CustomAlertPopupModel`, which supplies the card
//  background, title and Close button, so this view stays unstyled apart from its own rows.
//

import SwiftUI

struct UserAttendanceDetailsPopupContent: View {

    let details: [AttendanceDataModel.UserAttendanceDetail]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader
            Divider()

            if details.isEmpty {
                emptyMessage
            } else {
                rows
            }

            Divider()
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pieces
private extension UserAttendanceDetailsPopupContent {

    var columnHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Date")
            Spacer(minLength: 12)
            Text("Attendance Status")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.vertical, 10)
    }

    /// No `ScrollView`: the popup shows one clicked user's records, which is a single row in
    /// practice, and a scroll view would claim a fixed height and leave the card mostly empty.
    var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(details.enumerated()), id: \.offset) { index, detail in
                row(detail)
                if index < details.count - 1 { Divider() }
            }
        }
    }

    func row(_ detail: AttendanceDataModel.UserAttendanceDetail) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(detail.dateText)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer(minLength: 12)
            Text(detail.statusText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
    }

    var emptyMessage: some View {
        Text("No attendance records found.")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    var footer: some View {
        Text("\(details.count) total")
            .font(.system(size: 12.5))
            .foregroundColor(.secondary)
            .padding(.vertical, 10)
    }
}

#Preview {
    VStack(spacing: 24) {
        UserAttendanceDetailsPopupContent(details: [
            .init(attendanceDate: "2026-08-06T12:00:00", attendanceStatus: "Attended",
                  withdrewReason: nil, withdrewRemark: nil)
        ])

        UserAttendanceDetailsPopupContent(details: [
            .init(attendanceDate: "2026-08-06T12:00:00", attendanceStatus: "Attended",
                  withdrewReason: nil, withdrewRemark: nil),
            .init(attendanceDate: "2026-08-07T12:00:00", attendanceStatus: "Withdrew",
                  withdrewReason: "Personal", withdrewRemark: "Family event"),
            .init(attendanceDate: nil, attendanceStatus: nil,
                  withdrewReason: nil, withdrewRemark: nil)
        ])

        UserAttendanceDetailsPopupContent(details: [])
    }
    .padding()
}
