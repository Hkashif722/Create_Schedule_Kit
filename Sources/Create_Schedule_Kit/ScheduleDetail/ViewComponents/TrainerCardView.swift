//
//  TrainerCardView.swift
//  Create_Schedule_Kit
//
//  "TRAINER" card — avatar, name, "Trainer · type" and a type badge.
//

import SwiftUI
import SwiftUIUtilities

struct TrainerCardView: View {

    let name: String
    /// Nil when the server sends no type for this trainer — the badge is then dropped
    /// rather than guessed.
    let trainerType: String?

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(ColorUtility.primaryColor.opacity(0.15))
                .frame(width: 52, height: 52)
                .overlay(
                    Text(initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ColorUtility.primaryColor)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(trainerType.map { "Trainer · \($0)" } ?? "Trainer")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            if let trainerType {
                Text(trainerType)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }
        let joined = parts.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }
}

#Preview {
    VStack(spacing: 10) {
        TrainerCardView(name: "Kashif User", trainerType: "Internal")
        TrainerCardView(name: "Chetan Wade II-cw", trainerType: nil)
    }
    .padding()
}
