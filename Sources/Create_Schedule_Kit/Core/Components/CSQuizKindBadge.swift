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

/// Small rounded status chip ("Published", "Locked").
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

/// Yellow numbered circle in front of a quiz question.
struct CSQuestionNumberBadge: View {
    let number: Int
    var size: CGFloat = 28

    var body: some View {
        Text("\(number)")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(red: 0.55, green: 0.36, blue: 0.0))
            .frame(width: size, height: size)
            .background(Circle().fill(Color(red: 1.0, green: 0.85, blue: 0.40).opacity(0.7)))
            .accessibilityLabel("Question \(number)")
    }
}

#Preview {
    HStack {
        CSQuestionNumberBadge(number: 3)
        CSQuizKindBadge(kind: .pre)
        CSQuizKindBadge(kind: .post)
        CSStatusChip(title: "Published", tint: .green)
        CSStatusChip(title: "Locked", systemImage: "lock.fill", tint: .gray)
    }
    .padding()
}
