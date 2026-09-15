//
//  ProfileQRConfirmContent.swift
//  Create_Schedule_Kit
//
//  Body of the "mark this person?" popup. Naming who was scanned is the whole point — a
//  scan is a write, and the trainer should see whose attendance they are about to record.
//

import SwiftUI
import SwiftUIUtilities

struct ProfileQRConfirmContent: View {

    let name: String
    /// Already decrypted for display. Never posted.
    let email: String?
    let attendanceDate: String

    var body: some View {
        VStack(spacing: 10) {
            row(label: "User", value: name)
            if let email, !email.isEmpty {
                row(label: "Email", value: email)
            }
            row(label: "Date", value: attendanceDate)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
