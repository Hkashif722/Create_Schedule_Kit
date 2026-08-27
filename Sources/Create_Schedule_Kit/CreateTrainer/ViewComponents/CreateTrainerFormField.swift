//
//  CreateTrainerFormField.swift
//  Create_Schedule_Kit
//
//  One labelled field on the Create New Trainer sheet: an uppercase caption with a required
//  asterisk over a rounded, tinted input. Borrows the brand primary for the focused/filled
//  border so the sheet reads as part of the wizard.
//

import SwiftUI
import SwiftUIUtilities

struct CreateTrainerFormField: View {

    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .words
    /// Shown under the field once the value is non-empty but still not acceptable.
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Color(.darkGray))
                    .tracking(0.4)
                Text("*")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.red)
            }

            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium))
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil { return .red }
        return text.isEmpty ? Color(.systemGray4) : ColorUtility.primaryColor
    }
}

#Preview {
    VStack(spacing: 20) {
        CreateTrainerFormField(
            title: "User name",
            placeholder: "Enter trainer name",
            text: .constant("")
        )
        CreateTrainerFormField(
            title: "Email id",
            placeholder: "Enter email address",
            text: .constant("ketone@gmail"),
            keyboardType: .emailAddress,
            autocapitalization: .never,
            errorMessage: "Enter a valid email address."
        )
    }
    .padding()
}
