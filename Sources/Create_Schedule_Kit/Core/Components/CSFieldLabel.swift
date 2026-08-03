//
//  CSFieldLabel.swift
//  Create_Schedule_Kit
//
//  Shared field label with optional required asterisk.
//

import SwiftUI

struct CSFieldLabel: View {
    let title: String
    var isRequired: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(Color(.darkGray))
            if isRequired {
                Text("*")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
