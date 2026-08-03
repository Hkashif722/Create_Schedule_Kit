//
//  AttendanceUserRowView.swift
//  Create_Schedule_Kit
//
//  One selectable user row in the Update Attendance list: checkbox, initials avatar, name,
//  email, overall-status badge, and trailing view / delete buttons (delete gated by config).
//

import SwiftUI
import SwiftUIUtilities

struct AttendanceUserRowView: View {

    let user: AttendanceDataModel.AttendanceUser
    let isSelected: Bool
    let canDelete: Bool
    let onTap: () -> Void
    let onView: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onTap) { checkbox }
                .buttonStyle(.plain)
            avatar
            details
            Spacer(minLength: 8)
            actionButtons
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Pieces

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(isSelected ? ColorUtility.primaryColor : Color(.systemGray3), lineWidth: 1.8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? ColorUtility.primaryColor : Color.clear)
            )
            .frame(width: 24, height: 24)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(isSelected ? 1 : 0)
            )
    }

    private var avatar: some View {
        Circle()
            .fill(avatarColor.opacity(0.25))
            .frame(width: 46, height: 46)
            .overlay(
                Text(user.initials)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(avatarColor)
            )
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(user.displayName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            if let email = user.emailId, !email.isEmpty {
                Text(email)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let text = statusText {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(statusColor.opacity(0.15)))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            iconButton(systemName: "eye", tint: ColorUtility.primaryColor, action: onView)
            if canDelete {
                iconButton(systemName: "trash", tint: .red, action: onDelete)
            }
        }
    }

    private func iconButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var statusText: String? {
        guard let raw = user.overAllStatus?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        switch raw.lowercased() {
        case "notstarted": return "Not started"
        case "completed":  return "Completed"
        case "inprogress": return "In progress"
        default:           return raw
        }
    }

    private var statusColor: Color {
        switch (user.overAllStatus ?? "").lowercased() {
        case "completed":  return .green
        case "notstarted": return .orange
        case "inprogress": return ColorUtility.primaryColor
        default:           return .secondary
        }
    }

    private var avatarColor: Color {
        let palette: [Color] = [.orange, .pink, .purple, .green, .blue, .teal, .indigo, .red]
        let index = abs(user.id.hashValue) % palette.count
        return palette[index]
    }
}

#Preview {
    VStack(spacing: 0) {
        AttendanceUserRowView(
            user: .init(id: 1, scheduleID: 3787, userId: "anushkab", userName: "anushkab",
                        emailId: "anushkabawalekar39@gmail.com", mobileNumber: "xxxx",
                        isPresent: false, moduleID: 42182, courseID: 56288,
                        overAllStatus: "NotStarted", attendanceStatus: nil, attendanceDate: nil),
            isSelected: false, canDelete: true, onTap: {}, onView: {}, onDelete: {}
        )
        Divider()
        AttendanceUserRowView(
            user: .init(id: 2, scheduleID: 3787, userId: "kashif", userName: "kashif",
                        emailId: "khasif@gmail.com", mobileNumber: "xxxx",
                        isPresent: false, moduleID: 42182, courseID: 56288,
                        overAllStatus: "Completed", attendanceStatus: nil, attendanceDate: nil),
            isSelected: true, canDelete: false, onTap: {}, onView: {}, onDelete: {}
        )
    }
    .padding()
}
