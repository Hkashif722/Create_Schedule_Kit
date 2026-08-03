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
    let trainerType: String

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
                Text(name).font(.system(size: 17, weight: .bold)).foregroundColor(.primary)
                Text("Trainer · \(trainerType)").font(.system(size: 13)).foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            Text(trainerType)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.green.opacity(0.15)))
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
    TrainerCardView(name: "Kashif User", trainerType: "Internal")
        .padding()
}
