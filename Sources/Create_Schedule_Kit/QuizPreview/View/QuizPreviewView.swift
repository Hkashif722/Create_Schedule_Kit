//
//  QuizPreviewView.swift
//  Create_Schedule_Kit
//
//  Read-only Pre/Post quiz, pushed from a Schedule Details quiz row.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct QuizPreviewView: View {

    @StateObject private var viewModel: QuizPreviewViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.QuizPreviewNavModel) {
        _viewModel = StateObject(wrappedValue: QuizPreviewViewModel(router: router, navModel: navModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let summary = viewModel.summary {
                content(summary)
            } else if viewModel.loadFailed {
                loadFailedView
            } else {
                Spacer()
            }
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension QuizPreviewView {

    var header: some View {
        HStack(spacing: 8) {
            Button(action: viewModel.didTapBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text(viewModel.headerTitle)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    func content(_ summary: ScheduleQuizDataModel.QuizSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                QuizPreviewSummaryCard(
                    title: summary.title,
                    isPublished: summary.isPublished,
                    instructions: viewModel.instructions,
                    stats: viewModel.stats
                )
                Text("Questions")
                    .font(.system(size: 17, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if viewModel.sections.isEmpty {
                    Text("No questions yet.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.sections) { section in
                        QuizPreviewSectionCard(section: section)
                    }
                }
            }
            .padding()
        }
    }

    var loadFailedView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text("Couldn't load this quiz")
                .font(.system(size: 16, weight: .semibold))
            CSSecondaryButton(title: "Retry", systemImage: "arrow.clockwise", action: viewModel.didTapRetry)
                .frame(maxWidth: 200)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    QuizPreviewView(router: router, navModel: .init(quizID: 97, kind: .pre))
}
