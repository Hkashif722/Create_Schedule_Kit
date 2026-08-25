//
//  CancelScheduleWarningBanner.swift
//  Create_Schedule_Kit
//
//  Advisory banner at the top of the Cancel Schedule sheet, shown only when the schedule already
//  has nominated or requesting users. Tinted leading bar + info glyph, mirroring the web dialog's
//  callout.
//

import SwiftUI
import SwiftUIUtilities

struct CancelScheduleWarningBanner: View {

    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ColorUtility.primaryColor)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(ColorUtility.primaryColor.opacity(0.08))
        // Leading accent bar. Drawn as an overlay rather than an HStack element so the bar
        // stretches to the banner's full height whatever the text wraps to.
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ColorUtility.primaryColor)
                .frame(width: 4)
        }
        .cornerRadius(10)
    }
}

#Preview {
    VStack(spacing: 16) {
        CancelScheduleWarningBanner(
            message: "Users are already nominated or requested for the schedule, are you sure to cancel this schedule?"
        )
        CancelScheduleWarningBanner(message: "Short message.")
    }
    .padding()
}
