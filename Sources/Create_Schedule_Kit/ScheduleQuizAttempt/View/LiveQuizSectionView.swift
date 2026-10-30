//
//  LiveQuizSectionView.swift
//  Create_Schedule_Kit
//
//  Learner entry point: the "Live Quiz" block the host drops inline on a schedule card. Only
//  slots the manager created show up; Start / Resume / View result open full-screen on top.
//  Draws nothing until there's at least one row.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct LiveQuizSectionView: View {

    @StateObject private var viewModel: LearnerScheduleQuizViewModel

    init(router: AnyRouter, scheduleID: Int) {
        _viewModel = StateObject(
            wrappedValue: LearnerScheduleQuizViewModel(router: router, scheduleID: scheduleID)
        )
    }

    var body: some View {
        // container stays even when empty, so onAppear still fires
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.slots.isEmpty {
                rows
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension LiveQuizSectionView {

    var rows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Quiz")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            ForEach(viewModel.slots) { slot in
                LiveQuizRowView(slot: slot) { viewModel.didTapSlot(slot) }
            }
        }
        .padding(.top, 12)
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    LiveQuizSectionView(router: router, scheduleID: 4811)
        .padding()
}
