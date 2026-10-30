//
//  Create_Schedule_Kit.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

public struct Create_Schedule_Kit: Sendable {

    public init(config: CreateScheduleKitConfig) async {
        await CreateScheduleKitAPIManager.shared.configure(config)
    }

    /// Root entry point for the Create Schedule wizard.
    /// - Parameters:
    ///   - router: Router supplied by the host (from SwiftfulRouting).
    ///   - onFinish: Called when the wizard completes or is cancelled.
    @MainActor public func dashboard(
        router: AnyRouter,
        onFinish: ((CreateScheduleKitEvent) -> Void)? = nil
    ) -> some View {
        ScheduleListView(router: router, onFinish: onFinish)
    }

    /// Learner entry point: the schedule's Pre/Post quiz cards, with start / resume / result.
    /// Push it or show it full screen; it draws its own header, and back dismisses it.
    /// - Parameters:
    ///   - router: Router supplied by the host (from SwiftfulRouting).
    ///   - scheduleID: The ILT schedule id (the same id the host's schedule card holds).
    @MainActor public func scheduleQuizzes(router: AnyRouter, scheduleID: Int) -> some View {
        LearnerScheduleQuizView(router: router, scheduleID: scheduleID)
    }
}
