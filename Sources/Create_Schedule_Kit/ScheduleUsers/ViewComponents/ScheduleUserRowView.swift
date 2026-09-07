//
//  ScheduleUserRowView.swift
//  Create_Schedule_Kit
//
//  One row of the waiting / availability lists: initials avatar, name, login id, contact
//  details and the request's status. Read-only — neither list acts on its rows.
//

import SwiftUI
import SwiftUIUtilities

struct ScheduleUserRowView: View {

    let user: ScheduleUsersDataModel.ScheduleUser

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            details
            Spacer(minLength: 8)
            statusPill
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    private var avatar: some View {
        Circle()
            .fill(avatarColor.opacity(0.2))
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

            if let userId = user.userId, !userId.isEmpty {
                Text("ID: \(userId)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if let email = user.emailId, !email.isEmpty {
                contactRow(icon: "envelope", text: email)
            }

            if let phone = user.mobileNumber, !phone.isEmpty {
                contactRow(icon: "phone", text: phone)
            }
        }
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var statusPill: some View {
        Text(user.statusText)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(statusColor.opacity(0.15)))
    }

    private var statusColor: Color { user.isConfirmed ? .green : .orange }

    private var avatarColor: Color {
        let palette: [Color] = [.orange, .pink, .purple, .green, .blue, .teal, .indigo, .red]
        return palette[abs(user.id.hashValue) % palette.count]
    }
}

#Preview {
    VStack(spacing: 12) {
        ScheduleUserRowView(
            user: .init(
                id: 12277, userId: "sunny", userName: "Sunny Rasal",
                emailId: "sunny.rasal@dummy.com", mobileNumber: "xxxxxxxxxx",
                status: "True", trainingRequestStatus: "Pending",
                overAllStatus: "NotStarted", isPresent: false
            )
        )
        ScheduleUserRowView(
            user: .init(
                id: 12276, userId: "anurag", userName: "Anurag Singh",
                emailId: "anurag.singh@dummy.com", mobileNumber: "xxxxxxxxxx",
                status: "False", trainingRequestStatus: "Pending",
                overAllStatus: "Completed", isPresent: false
            )
        )
    }
    .padding()
    .background(Color.scheduleBackground)
}
