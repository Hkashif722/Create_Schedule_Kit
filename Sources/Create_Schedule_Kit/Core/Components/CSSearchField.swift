//
//  CSSearchField.swift
//  Create_Schedule_Kit
//
//  The package's search box: magnifying glass, text, and a trailing control that is a
//  spinner while a query is in flight and a clear button once there is something to clear.
//
//  Schedule List and the feedback picker each grew their own copy of this before it
//  existed; new screens use this one.
//

import SwiftUI
import SwiftUIUtilities

struct CSSearchField: View {

    @Binding var text: String
    var placeholder: String = "Search…"
    /// Shows the inline spinner in place of the clear button.
    var isSearching: Bool = false
    let onTextChanged: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: text) { newValue in onTextChanged(newValue) }

            // Searching reports itself here rather than behind a full-screen overlay.
            if isSearching {
                ProgressView().scaleEffect(0.8)
            } else if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview("Empty") {
    CSSearchField(text: .constant(""), placeholder: "Search users…", onTextChanged: { _ in })
        .padding()
}

#Preview("Searching") {
    CSSearchField(text: .constant("sunny"), placeholder: "Search users…", isSearching: true, onTextChanged: { _ in })
        .padding()
}
