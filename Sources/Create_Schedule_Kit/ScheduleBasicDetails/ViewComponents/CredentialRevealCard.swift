//
//  CredentialRevealCard.swift
//  Create_Schedule_Kit
//
//  Shows the selected webinar provider credential with a reveal (eye) toggle.
//

import SwiftUI
import SwiftUIUtilities

struct CredentialRevealCard: View {
    let providerTitle: String
    let displayValue: String
    let username: String?
    let isRevealed: Bool
    let onToggleReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(providerTitle) credentials")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Account")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(displayValue)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button(action: onToggleReveal) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundColor(ColorUtility.primaryColor)
                }
                .buttonStyle(.plain)
            }

            if let username, !username.isEmpty {
                Text("Username: \(username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(ColorUtility.primaryColor.opacity(0.06))
        .cornerRadius(12)
    }
}
