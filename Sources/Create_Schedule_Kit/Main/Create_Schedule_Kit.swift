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

    /// Learner entry point: the schedule's "Live Quiz" rows (Pre / Post) with start / resume /
    /// result. Drop it inline on the schedule card; it draws nothing when the schedule has no quiz.
    /// - Parameters:
    ///   - router: Router of the screen holding the card. The player and result open full screen on it.
    ///   - scheduleID: The ILT schedule id (the same id the host's schedule card holds).
    @MainActor public func liveQuiz(router: AnyRouter, scheduleID: Int) -> some View {
        LiveQuizSectionView(router: router, scheduleID: scheduleID)
    }
}
