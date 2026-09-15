//
//  AttendanceActionTileView.swift
//  Create_Schedule_Kit
//
//  One way to mark attendance — Scan QR, Bulk mark, Download. Three sit side by side under
//  MARK ATTENDANCE.
//
//  The icon sits above the label rather than beside it: three equal tiles leave about 100pt
//  each, and an icon on the left ate enough of that to truncate "Bulk mark" and "Download".
//  Stacked, the label gets the tile's full width.
//

import SwiftUI
import SwiftUIUtilities

struct AttendanceActionTileView: View {

    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ColorUtility.primaryColor)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(ColorUtility.primaryColor.opacity(0.12)))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    // Shrinks rather than truncating if the label or the type size grows.
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 10) {
        AttendanceActionTileView(title: "Scan QR", systemImage: "qrcode.viewfinder", action: {})
        AttendanceActionTileView(title: "Bulk mark", systemImage: "checkmark.circle", action: {})
        AttendanceActionTileView(title: "Download", systemImage: "arrow.down.circle", action: {})
    }
    .padding()
}
