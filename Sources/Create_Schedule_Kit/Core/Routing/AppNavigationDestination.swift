//
//  AppNavigationDestination.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

// MARK: - Navigation Destination
@MainActor
enum AppNavigationDestination {
    // Package destinations (SwiftUIUtilities built-ins)
    case packageDestination(NavigationDestination)

    // App-specific destinations
    case holidaysSheet(NavigationViewModel.HolidaysSheetNavModel)
    case feedbackPicker(NavigationViewModel.FeedbackPickerNavModel)
    case createTrainer(NavigationViewModel.CreateTrainerNavModel)
    case nominateUsers(NavigationViewModel.NominateUsersNavModel)
    case createWizard
    case editWizard(scheduleID: Int)
    case scheduleDetail(NavigationViewModel.ScheduleDetailNavModel)
    case attendance(NavigationViewModel.AttendanceNavModel)
    case cancelSchedule(NavigationViewModel.CancelScheduleNavModel)
}

// MARK: - Navigation Protocol Conformance
extension AppNavigationDestination: NavigationProtocol {

    public func navigate(using router: AnyRouter) {

        switch self {

        case .packageDestination(let destination):
            destination.navigate(using: router)

        case .holidaysSheet(let navModel):
            showResizableSheet(router) { router in
                HolidaysSheetView(router: router, navModel: navModel)
            }

        case .feedbackPicker(let navModel):
            showResizableSheet(router) { router in
                FeedbackModulePickerSheet(router: router, navModel: navModel)
            }

        case .createTrainer(let navModel):
            showResizableSheet(router) { router in
                CreateTrainerView(router: router, navModel: navModel)
            }

        case .nominateUsers(let navModel):
            showFullSheetWithDragGesture(router) { router in
                NominateUsersView(router: router, navModel: navModel)
            }

        case .createWizard:
            pushScreen(router) { router in
                CreateScheduleWizardView(router: router, onFinish: nil)
            }

        case .editWizard(let scheduleID):
            pushScreen(router) { router in
                CreateScheduleWizardView(router: router, mode: .edit(scheduleID: scheduleID), onFinish: nil)
            }

        case .scheduleDetail(let navModel):
            pushScreen(router) { router in
                ScheduleDetailView(router: router, navModel: navModel)
            }

        case .attendance(let navModel):
            pushScreen(router) { router in
                AttendanceView(router: router, navModel: navModel)
            }

        // Large detent rather than resizable: the sheet hosts a focused text editor, and a
        // medium detent would sit behind the keyboard.
        case .cancelSchedule(let navModel):
            showFullSheetWithDragGesture(router) { router in
                CancelScheduleView(router: router, navModel: navModel)
            }
        }
    }
}
