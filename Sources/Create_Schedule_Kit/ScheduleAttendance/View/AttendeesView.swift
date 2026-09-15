//
//  AttendeesView.swift
//  Create_Schedule_Kit
//
//  Who is on this schedule, read-only: no checkboxes, no Select all, no Save. The eye opens
//  a user's attendance history and the trash removes a record when `ATTNOM_DEL` allows it.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct AttendeesView: View {

    @StateObject private var viewModel: AttendanceUsersViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.AttendanceUsersNavModel) {
        _viewModel = StateObject(
            wrappedValue: AttendanceUsersViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        content
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .loadingOverlayViewPkg(state: viewModel.loadingState)
            .toastViewPkg(toast: $viewModel.toast)
            .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Content
private extension AttendeesView {

    @ViewBuilder
    var content: some View {
        if viewModel.loadingState.isLoading && viewModel.items.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            list
        }
    }

    var list: some View {
        ScrollView {
            AttendanceSectionCard(title: sectionTitle, contentPadding: 0) {
                AttendanceUsersListView(
                    items: viewModel.items,
                    isLoading: viewModel.loadingState.isLoading,
                    isLoadingMore: viewModel.isLoadingMore,
                    isSelectable: viewModel.mode.isSelectable,
                    canDelete: viewModel.canDelete,
                    emptyMessage: viewModel.mode.emptyMessage,
                    emptyIcon: viewModel.mode.emptyIcon,
                    isSelected: { _ in false },
                    onTap: { _ in },
                    onView: { viewModel.didTapViewUser($0) },
                    onDelete: { viewModel.didTapDeleteUser($0) },
                    onReachEnd: { viewModel.loadMoreIfNeeded(currentItem: $0) }
                )
            }
            .padding(16)
        }
    }

    /// The caption stays put so the screen reads the same whether or not it has rows, and
    /// the message sits above centre — the package's standard empty shape.
    var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.mode.sectionTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            Spacer()

            VStack(spacing: 10) {
                Image(systemName: viewModel.mode.emptyIcon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(viewModel.mode.emptyMessage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Nominate users to this schedule to see them here.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var sectionTitle: String {
        viewModel.totalUsersCount > 0
            ? "\(viewModel.mode.sectionTitle) (\(viewModel.totalUsersCount))"
            : viewModel.mode.sectionTitle
    }
}
