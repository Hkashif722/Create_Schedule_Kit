//
//  CSQuizKindBadge.swift
//  Create_Schedule_Kit
//
//  The "PRE" / "POST" pill shown wherever a schedule quiz is named.
//

import SwiftUI

struct CSQuizKindBadge: View {
    let kind: ScheduleQuizDataModel.QuizKind

    var body: some View {
        Text(kind.badge)
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(kind.badgeForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(kind.badgeBackground)
            )
            .fixedSize()
            .accessibilityLabel(kind == .pre ? "Pre" : "Post")
    }
}

/// Small rounded status chip ("Draft", "Published", "Locked").
struct CSStatusChip: View {
    let title: String
    var systemImage: String? = nil
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(title).font(.system(size: 11.5, weight: .bold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.14)))
        .fixedSize()
    }
}

#Preview {
    HStack {
        CSQuizKindBadge(kind: .pre)
        CSQuizKindBadge(kind: .post)
        CSStatusChip(title: "Draft", tint: .orange)
        CSStatusChip(title: "Locked", systemImage: "lock.fill", tint: .gray)
    }
    .padding()
}
