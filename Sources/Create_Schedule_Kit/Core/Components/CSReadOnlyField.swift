//
//  CSReadOnlyField.swift
//  Create_Schedule_Kit
//
//  Locked (read-only) form field: label + value in a grey lock-box. Used in the
//  edit-schedule flow for identity fields the API does not allow changing
//  (course, module, categories, webinar type). Mirrors the schedule-code field style.
//

import SwiftUI

struct CSReadOnlyField: View {
    let title: String
    let value: String
    var isRequired: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: title, isRequired: isRequired)
            HStack {
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "lock.fill").foregroundColor(.secondary).font(.caption)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CSReadOnlyField(title: "Course name", value: "Schedule Creation", isRequired: true)
        CSReadOnlyField(title: "Category", value: "")
    }
    .padding()
}
