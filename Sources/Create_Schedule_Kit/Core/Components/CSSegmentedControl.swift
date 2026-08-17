//
//  CSSegmentedControl.swift
//  Create_Schedule_Kit
//
//  Generic pill segmented control for small option sets (delivery mode, trainer type).
//  Selected segment uses a tinted primary fill + primary border; unselected is outlined.
//

import SwiftUI
import SwiftUIUtilities

struct CSSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    /// Optional leading SF Symbol per option (e.g. wifi / building for delivery mode).
    var icon: (Option) -> String? = { _ in nil }
    /// When false the control is display-only (locked fields in the edit flow).
    var isEnabled: Bool = true
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    guard isEnabled else { return }
                    selection = option
                } label: {
                    HStack(spacing: 6) {
                        if let symbol = icon(option) {
                            Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                        }
                        Text(title(option)).font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .foregroundColor(isSelected ? ColorUtility.primaryColor : .primary)
                    .background(isSelected ? ColorUtility.primaryColor.opacity(0.12) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? ColorUtility.primaryColor : Color(.systemGray4),
                                    lineWidth: isSelected ? 1.5 : 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(isEnabled ? 1 : 0.55)
    }
}
