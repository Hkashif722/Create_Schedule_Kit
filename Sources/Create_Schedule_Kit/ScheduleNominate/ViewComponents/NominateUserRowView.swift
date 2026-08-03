//
//  NominateUserRowView.swift
//  Create_Schedule_Kit
//
//  One selectable user row in the Nominate Users list: checkbox, initials avatar,
//  name, ID badge, email and (server-masked) phone number.
//

import SwiftUI
import SwiftUIUtilities

struct NominateUserRowView: View {

    let user: NominateUsersDataModel.NominationUser
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                checkbox
                avatar
                details
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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
            .padding(.top, 2)
    }

    private var avatar: some View {
        Circle()
            .fill(avatarColor.opacity(0.25))
            .frame(width: 46, height: 46)
            .overlay(
                Text(initials)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(avatarColor)
            )
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(user.displayName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)

            if let userId = user.userId, !userId.isEmpty {
                Text("ID · \(userId)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ColorUtility.primaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ColorUtility.primaryColor.opacity(0.12)))
            }

            if let email = user.emailId, !email.isEmpty {
                Text(email)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            if let phone = user.mobileNumber, !phone.isEmpty {
                Text(phone)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var initials: String {
        let parts = user.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        let joined = parts.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }

    private var avatarColor: Color {
        let palette: [Color] = [.orange, .pink, .purple, .green, .blue, .teal, .indigo, .red]
        let index = abs(user.id.hashValue) % palette.count
        return palette[index]
    }
}

#Preview {
    VStack(spacing: 0) {
        NominateUserRowView(
            user: .init(id: 1, userId: "sbil", userName: "SBIL Demo",
                        emailId: "sbil.demo@gmail.com", mobileNumber: "+91 85•• ••598", status: "True"),
            isSelected: false,
            onTap: {}
        )
        NominateUserRowView(
            user: .init(id: 2, userId: "kevin02", userName: "Kevin George",
                        emailId: "kevin.g@mail.com", mobileNumber: "+91 80•• ••327", status: "True"),
            isSelected: true,
            onTap: {}
        )
    }
}
