//
//  CreateScheduleKitEvent.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation

// MARK: - Package Events
/// Cross-cutting events emitted from inside the package (e.g. to notify the host
/// app of schedule lifecycle changes). Consumed via `CreateScheduleKitEventPublisher`.
public enum CreateScheduleKitEvent {
    case scheduleCreated(scheduleCode: String)
    case scheduleUpdated(scheduleCode: String)
    case cancelled
}
