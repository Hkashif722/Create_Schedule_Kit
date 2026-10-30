//
//  QuizOptionRowView.swift
//  Create_Schedule_Kit
//
//  One answer option. Lettered circle for single selection, lettered square (tick when picked)
//  for multiple selection.
//

import SwiftUI

struct QuizOptionRowView: View {
    let letter: String
    let text: String
    let isSelected: Bool
    let isMultiple: Bool
    var isEnabled: Bool = true
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                marker
                Text(text)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? CSTheme.primaryColor.opacity(0.08) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? CSTheme.primaryColor : Color(.systemGray4), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .accessibilityLabel("Option \(letter), \(text)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var marker: some View {
        let shape = RoundedRectangle(cornerRadius: isMultiple ? 6 : 15, style: .continuous)
        ZStack {
            shape
                .fill(isSelected ? CSTheme.primaryColor : Color.clear)
            shape
                .strokeBorder(isSelected ? CSTheme.primaryColor : Color(.systemGray3), lineWidth: 1.5)
            if isSelected && isMultiple {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(CSTheme.primaryColor.getDynamicTextColor)
            } else {
                Text(letter)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? CSTheme.primaryColor.getDynamicTextColor : .secondary)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 10) {
        QuizOptionRowView(letter: "A", text: "Learning Content Management System",
                          isSelected: true, isMultiple: false, onTap: {})
        QuizOptionRowView(letter: "B", text: "Learning Course Module Software",
                          isSelected: false, isMultiple: false, onTap: {})
        QuizOptionRowView(letter: "C", text: "Fuel", isSelected: true, isMultiple: true, onTap: {})
        QuizOptionRowView(letter: "D", text: "Oxygen", isSelected: false, isMultiple: true, onTap: {})
    }
    .padding()
}
