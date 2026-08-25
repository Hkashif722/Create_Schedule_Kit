//
//  HolidayRowView.swift
//  Create_Schedule_Kit
//
//  Single day row in the Holidays sheet: date tile, working/weekend state, toggle.
//  The range's first/last day arrive locked — captioned and un-togglable.
//

import SwiftUI
import SwiftUIUtilities

struct HolidayRowView: View {
    let day: HolidayDay
    /// "Start date" / "End date" when this row is locked, `nil` when it can be marked.
    let lockCaption: String?
    let onToggle: () -> Void
    let onLabelChange: (String) -> Void

    @State private var labelText: String = ""

    private func formatted(_ format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale.current
        return f.string(from: day.date)
    }

    private var monthText: String { formatted("MMM").uppercased() }
    private var dayNumber: String { formatted("d") }
    private var weekdayLine: String { formatted("EEEE · MMM d, yyyy") }

    var body: some View {
        HStack(spacing: 12) {
            dateTile

            VStack(alignment: .leading, spacing: 6) {
                Text(weekdayLine)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                if let lockCaption {
                    Text(lockCaption)
                        .font(.system(size: 15, weight: .bold))
                } else if day.isHoliday {
                    TextField("Holiday name", text: $labelText)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .onChange(of: labelText) { newValue in onLabelChange(newValue) }
                } else {
                    Text("Working day")
                        .font(.system(size: 15, weight: .bold))
                }
            }

            Spacer(minLength: 8)

            if lockCaption != nil {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            } else {
                Toggle("", isOn: Binding(get: { day.isHoliday }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .tint(ColorUtility.primaryColor)
            }
        }
        .padding(12)
        .background(day.isHoliday ? ColorUtility.primaryColor.opacity(0.06) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(day.isHoliday ? ColorUtility.primaryColor.opacity(0.25) : Color(.systemGray5), lineWidth: 1)
        )
        .opacity(lockCaption == nil ? 1 : 0.55)
        .onAppear { labelText = day.label }
    }

    private var dateTile: some View {
        VStack(spacing: 0) {
            Text(monthText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(day.isHoliday ? ColorUtility.primaryColor : .secondary)
            Text(dayNumber)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(day.isHoliday ? ColorUtility.primaryColor : .primary)
        }
        .frame(width: 54, height: 54)
        .background(day.isHoliday ? ColorUtility.primaryColor.opacity(0.12) : Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
