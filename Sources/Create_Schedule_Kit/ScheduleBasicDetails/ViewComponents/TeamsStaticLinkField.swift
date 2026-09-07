//
//  TeamsStaticLinkField.swift
//  Create_Schedule_Kit
//
//  The required Microsoft Teams meeting link on Step 1 — the organiser pastes it by hand,
//  and only while `ATPTLWCS` is on. Reuses `MultilineTextInputField` (iOS-15 safe on its
//  own) with the character cap raised, since the package default truncates real links.
//

import SwiftUI
import SwiftUIUtilities

struct TeamsStaticLinkField: View {

    let title: String
    let text: String
    /// Non-nil once the typed value cannot be a meeting link — drives the red affordance.
    let errorMessage: String?
    let onTextChanged: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: title, isRequired: true)

            SwiftUIUtility.MultilineTextInputField(
                initialText: text,
                placeholder: "Paste or type the meeting link",
                minHeight: 90,
                cornerRadius: 12,
                borderColor: borderColor,
                backgroundColor: Color(.systemBackground),
                // The package default (250) truncates a real Teams `meetup-join` link.
                maxCharacters: WebinarLinkRules.maxLinkCharacters,
                onTextChanged: { value, _ in onTextChanged(value) }
            )
            // Plain free text. Left to its own devices the keyboard "corrects" a typed URL
            // into prose — `team.link` comes out as `Team link` — so autocorrect, the
            // capitalizing and the spell checker are all off, and the URL keyboard puts
            // `/` and `.` within reach. These propagate to the field's inner text input.
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }

    /// Matches `CSTextField`'s neutral/emphasized pair, plus the red state it lacks.
    private var borderColor: Color {
        if errorMessage != nil { return .red }
        return text.isEmpty ? Color(.systemGray4) : ColorUtility.primaryColor
    }
}

#Preview("Teams link — empty") {
    TeamsStaticLinkField(
        title: "Teams Link",
        text: "",
        errorMessage: nil,
        onTextChanged: { _ in }
    )
    .padding()
}

#Preview("Teams link — invalid") {
    TeamsStaticLinkField(
        title: "Teams Link",
        text: "team.link",
        errorMessage: "Enter a valid meeting link starting with https://",
        onTextChanged: { _ in }
    )
    .padding()
}
