//
//  LearnerQuizTopBar.swift
//  Create_Schedule_Kit
//
//  Header strip of the player and result screens: PRE/POST badge, quiz title, and whatever
//  the screen puts on the right (timer + Exit, or a close button).
//

import SwiftUI

struct LearnerQuizTopBar<Trailing: View>: View {
    let kind: ScheduleQuizDataModel.QuizKind
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            CSQuizKindBadge(kind: kind)
            Text(title.isEmpty ? kind.slotTitle : title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            // title truncates, timer + Exit dont. else it reads "09..." and "Exi/t"
            trailing
                .fixedSize()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }
}

#Preview {
    LearnerQuizTopBar(kind: .pre, title: "class56 — pre check") {
        Text("Exit").font(.system(size: 14, weight: .semibold))
    }
}
