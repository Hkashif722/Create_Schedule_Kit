//
//  NomineeRowView.swift
//  Create_Schedule_Kit
//
//  One nominee row on the Schedule Details screen: avatar, name/email, status pill, delete.
//

import SwiftUI
import SwiftUIUtilities

struct NomineeRowView: View {

    let nominee: ScheduleDetailDataModel.Nominee
    let onDelete: () -> Void
    /// An external trainer reads the nominee list without being able to change it.
    var canDelete: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(avatarColor.opacity(0.2))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(initials)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(avatarColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(nominee.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                if let email = nominee.emailId, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            Text(nominee.statusText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(nominee.isConfirmed ? .green : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill((nominee.isConfirmed ? Color.green : Color.orange).opacity(0.15)))

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    private var initials: String {
        let parts = nominee.displayName.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }
        let joined = parts.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }

    private var avatarColor: Color {
        let palette: [Color] = [.orange, .pink, .purple, .green, .blue, .teal, .indigo, .red]
        return palette[abs(nominee.id.hashValue) % palette.count]
    }
}

#Preview {
    NomineeRowView(
        nominee: .init(id: 1, userId: "kevin", userName: "Kevin H", emailId: "kevin.h@mail.com",
                       mobileNumber: nil, status: "True", trainingRequestStatus: "Registered",
                       overAllStatus: "NotStarted", isPresent: false),
        onDelete: {}
    )
    .padding()
}
