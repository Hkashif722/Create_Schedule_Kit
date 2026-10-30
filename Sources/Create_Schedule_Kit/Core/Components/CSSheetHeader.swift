//
//  CSSheetHeader.swift
//  Create_Schedule_Kit
//
//  Title row for bottom sheets: bold title, optional subtitle, close button. The close button
//  stays because iOS 15 sheets get no drag indicator from the router.
//

import SwiftUI
import SwiftUIUtilities

struct CSSheetHeader: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            SwiftUIUtility.CircleCloseButton(
                foregroundColor: .secondary,
                backgroundColor: Color(.systemGray6),
                size: 36,
                action: onClose
            )
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

#Preview {
    CSSheetHeader(
        title: "Write a new question",
        subtitle: "Saved straight into the question bank, so it can be reused in other quizzes and packages.",
        onClose: {}
    )
}
