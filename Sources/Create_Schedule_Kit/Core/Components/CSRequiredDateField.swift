//
//  CSRequiredDateField.swift
//  Create_Schedule_Kit
//
//  A required labelled date field that opens the shared calendar modal. Unlike
//  SwiftUIUtilities' `DatePickerTextFieldPkg`, it renders a red border while no date is
//  selected (required-field affordance) and a neutral border once a date is chosen.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct CSRequiredDateField: View {

    let router: AnyRouter
    let title: String
    var placeHolder: String = "Select date"
    var minimumDate: Date? = nil
    var maximumDate: Date? = nil
    var initialDateString: String? = nil
    let onDateSelected: (Date) -> Void

    @State private var selectedDate: Date?

    private var displayDate: Date? {
        selectedDate ?? initialDateString.flatMap(Self.parse)
    }

    private var borderColor: Color {
        displayDate == nil ? .red : Color(.systemGray4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: title, isRequired: true)

            Button(action: showDatePickerModal) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ColorUtility.primaryColor)
                    Text(displayDate.map(Self.format) ?? placeHolder)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(displayDate == nil ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func showDatePickerModal() {
        let navModel = NavigationViewModel.SUIDatePickerNavModel(
            initialDate: displayDate ?? minimumDate ?? Date(),
            allowFutureDates: true,
            minimumDate: minimumDate,
            maximumDate: maximumDate,
            onDateSelected: { date in
                selectedDate = date
                onDateSelected(date)
            }
        )
        NavigationService.shared.navigate(using: router, to: NavigationDestination.datePicker(navModel))
    }

    // MARK: - Date formatting (host's configurable format)

    private static var configuredFormat: String {
        CreateScheduleKitAPIManager.shared.getConfiguaredDate
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = configuredFormat
        f.locale = Locale.current
        return f.string(from: date)
    }

    private static func parse(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let f = DateFormatter()
        f.dateFormat = configuredFormat
        f.locale = Locale.current
        return f.date(from: string)
    }
}
