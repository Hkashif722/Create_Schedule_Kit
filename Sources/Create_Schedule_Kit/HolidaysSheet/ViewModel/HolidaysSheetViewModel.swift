//
//  HolidaysSheetViewModel.swift
//  Create_Schedule_Kit
//
//  Generates and edits the per-day holiday list for the schedule range (no API).
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities

final class HolidaysSheetViewModel: BaseViewModel {

    private let navModel: NavigationViewModel.HolidaysSheetNavModel

    @Published var days: [HolidayDay]

    init(router: AnyRouter, navModel: NavigationViewModel.HolidaysSheetNavModel) {
        self.navModel = navModel
        self.days = HolidayDay.generate(
            start: navModel.startDate,
            end: navModel.endDate,
            existing: navModel.existing
        )
        super.init(router: router)
    }

    var markedCount: Int { days.filter { $0.isHoliday }.count }

    var subtitle: String {
        markedCount > 0 ? "\(markedCount) holiday\(markedCount > 1 ? "s" : "") marked" : "Schedule spans \(days.count) day\(days.count > 1 ? "s" : "")"
    }

    /// Caption shown instead of a toggle on the two locked boundary rows; `nil` for any day
    /// the user can actually mark.
    func lockCaption(for day: HolidayDay) -> String? {
        guard day.isLocked else { return nil }
        return day.id == days.first?.id ? "Start date" : "End date"
    }
}

// MARK: - Actions
extension HolidaysSheetViewModel {

    func toggle(_ day: HolidayDay) {
        guard let index = days.firstIndex(where: { $0.id == day.id }), !days[index].isLocked else { return }
        days[index].isHoliday.toggle()
        if !days[index].isHoliday {
            days[index].label = "Working"
        } else if days[index].label == "Working" {
            days[index].label = "Holiday"
        }
    }

    func updateLabel(_ day: HolidayDay, _ text: String) {
        guard let index = days.firstIndex(where: { $0.id == day.id }), !days[index].isLocked else { return }
        days[index].label = text
    }

    func save() {
        navModel.onSave(days)
        Task { @MainActor [weak self] in self?.router.dismissScreen() }
    }

    func close() {
        Task { @MainActor [weak self] in self?.router.dismissScreen() }
    }
}
