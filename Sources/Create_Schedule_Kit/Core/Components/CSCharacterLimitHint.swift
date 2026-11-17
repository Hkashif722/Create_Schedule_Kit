//
//  CSCharacterLimitHint.swift
//  Create_Schedule_Kit
//
//  "Up to N characters" + live "n/N" counter under a capped text field.
//

import SwiftUI

struct CSCharacterLimitHint: View {
    let count: Int
    let limit: Int

    var body: some View {
        HStack {
            Text("Up to \(limit) characters")
            Spacer()
            Text(verbatim: "\(count)/\(limit)")
                .foregroundStyle(count > limit ? Color.red : Color.secondary)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Up to \(limit) characters")
        .accessibilityValue("\(count) used")
    }
}

#Preview {
    VStack(spacing: 12) {
        CSCharacterLimitHint(count: 0, limit: 1500)
        CSCharacterLimitHint(count: 54, limit: 500)
        CSCharacterLimitHint(count: 201, limit: 200)
    }
    .padding()
}
