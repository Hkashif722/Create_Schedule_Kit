//
//  AttendanceSectionCard.swift
//  Create_Schedule_Kit
//
//  The attendance screens' section: a small caption, an optional trailing action, and a
//  shadowed card. Lifted from the private `card {}` wrapper the one-screen version used, so
//  all three screens keep the same chrome.
//

import SwiftUI
import SwiftUIUtilities

struct AttendanceSectionCard<Content: View, Accessory: View>: View {

    let title: String
    /// Zero for a card whose content is rows — `AttendanceUserRowView` carries its own
    /// padding, and adding the card's on top leaves one attendee floating in white space.
    var contentPadding: CGFloat = 16
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer(minLength: 8)
                accessory()
            }

            VStack(alignment: .leading, spacing: contentPadding == 0 ? 0 : 14) {
                content()
            }
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
        }
    }
}

extension AttendanceSectionCard where Accessory == EmptyView {
    init(
        title: String,
        contentPadding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            contentPadding: contentPadding,
            accessory: { EmptyView() },
            content: content
        )
    }
}
