//
//  ScheduleInfoCardView.swift
//  Create_Schedule_Kit
//
//  "SCHEDULE INFO" card — a list of label → value rows separated by dividers.
//

import SwiftUI

struct ScheduleInfoRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct ScheduleInfoCardView: View {

    let rows: [ScheduleInfoRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top) {
                    Text(row.label)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 12)
                    Text(row.value)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 14)
                if index < rows.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }
}

#Preview {
    ScheduleInfoCardView(rows: [
        .init(label: "Code", value: "SC6572"),
        .init(label: "Module", value: "test parichay"),
        .init(label: "Reg. end", value: "24 Jun 2026"),
        .init(label: "Coordinator", value: "Sachin Shimpi"),
        .init(label: "Seat capacity", value: "20"),
        .init(label: "Purpose", value: "Planned Training")
    ])
    .padding()
}
