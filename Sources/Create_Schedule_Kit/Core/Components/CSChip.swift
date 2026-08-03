//
//  CSChip.swift
//  Create_Schedule_Kit
//
//  Removable / selectable chip used for trainers and tags.
//

import SwiftUI
import SwiftUIUtilities

/// A chip showing a title with a trailing remove (x) control.
struct CSRemovableChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundColor(ColorUtility.primaryColor)
        .background(ColorUtility.primaryColor.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// A togglable selection chip (used for the tags picker).
struct CSSelectableChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(isSelected ? ColorUtility.primaryColor.getDynamicTextColor : .primary)
                .background(isSelected ? ColorUtility.primaryColor : Color(.systemGray6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
