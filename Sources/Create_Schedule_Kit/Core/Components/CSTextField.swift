//
//  CSTextField.swift
//  Create_Schedule_Kit
//
//  Labelled single-line text field. Supports read-only (auto-populated / disabled) mode and an
//  optional character cap with an "Up to N characters" counter.
//

import SwiftUI
import SwiftUIUtilities

struct CSTextField: View {
    let title: String
    var isRequired: Bool = false
    let placeholder: String
    @Binding var text: String
    var isReadOnly: Bool = false
    var keyboardType: UIKeyboardType = .default
    /// Optional leading SF Symbol (e.g. "phone" for a contact number).
    var leadingSystemImage: String? = nil
    var characterLimit: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: title, isRequired: isRequired)

            HStack(spacing: 8) {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                TextField(placeholder, text: $text)
                    .font(.system(size: 16, weight: .medium))
                    .keyboardType(keyboardType)
                    .disabled(isReadOnly)
                    .foregroundColor(isReadOnly ? .secondary : .primary)
                    .onChange(of: text) { newValue in
                        guard let characterLimit, newValue.count > characterLimit else { return }
                        text = String(newValue.prefix(characterLimit))
                    }
            }
            .padding(14)
            .background(isReadOnly ? Color(.systemGray6) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )

            if let characterLimit {
                CSCharacterLimitHint(count: text.count, limit: characterLimit)
            }
        }
    }

    /// Read-only fields stay neutral (they're always populated, so they must not pick up
    /// the emphasized/branded border). Editable fields highlight once they have content.
    private var borderColor: Color {
        if isReadOnly { return Color(.systemGray4) }
        return text.isEmpty ? Color(.systemGray4) : CSTheme.primaryColor
    }
}
