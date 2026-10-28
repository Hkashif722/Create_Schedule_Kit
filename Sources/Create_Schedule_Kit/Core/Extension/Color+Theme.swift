//
//  Color+Theme.swift
//  Create_Schedule_Kit
//
//  Package-local theme colors.
//

import SwiftUI
import SwiftUIUtilities

extension Color {
    /// Create Schedule wizard screen background (#F2EDF6).
    static let scheduleBackground = Color(red: 242 / 255, green: 237 / 255, blue: 246 / 255)
}

// host brand colors, set from cfg in configure(). defaults = SwiftUIUtility red/yellow
enum CSTheme {
    nonisolated(unsafe) static var primaryColor: Color = ColorUtility.primaryColor
    nonisolated(unsafe) static var secondaryColor: Color = ColorUtility.secondaryColor
}
