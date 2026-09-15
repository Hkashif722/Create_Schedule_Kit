//
//  AttendanceUsersMode.swift
//  Create_Schedule_Kit
//
//  Which of the two user-list screens is on screen. Both are driven by
//  `AttendanceUsersViewModel`: Bulk Mark selects people and saves a status against them,
//  Attendees only reads. Pure, so the contract between the two is testable without
//  standing up either view.
//

import Foundation

enum AttendanceUsersMode: String, CaseIterable, Equatable {
    case bulkMark
    case attendees

    var title: String {
        switch self {
        case .bulkMark:  return "Bulk Mark Attendance"
        case .attendees: return "Attendees"
        }
    }

    /// Checkboxes, Select all, and the "Show N" page-size menu.
    var isSelectable: Bool {
        switch self {
        case .bulkMark:  return true
        case .attendees: return false
        }
    }

    /// The Save Attendance footer. Only meaningful where a selection exists.
    var showsSaveFooter: Bool { isSelectable }

    /// The Attendance Status dropdown, and therefore the `ATTDSTATUS` fetch. Attendees
    /// writes nothing, so it does not ask for the list.
    var needsStatusOptions: Bool { isSelectable }

    /// The Attendance / Nomination tab bar. Nominating from here inserts attendance rows
    /// directly, which only makes sense alongside a status.
    var offersNominationTab: Bool { isSelectable }

    var sectionTitle: String {
        switch self {
        case .bulkMark:  return "ATTENDEES"
        case .attendees: return "ATTENDEES"
        }
    }

    var emptyMessage: String {
        switch self {
        case .bulkMark:  return "No users found"
        case .attendees: return "No attendees yet"
        }
    }

    var emptyIcon: String {
        switch self {
        case .bulkMark:  return "person.2"
        case .attendees: return "person.crop.circle.badge.questionmark"
        }
    }
}
