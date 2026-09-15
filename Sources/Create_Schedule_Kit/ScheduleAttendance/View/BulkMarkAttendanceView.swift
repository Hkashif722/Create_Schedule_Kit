//
//  BulkMarkAttendanceView.swift
//  Create_Schedule_Kit
//
//  Marks a status against several attendees at once. The day being marked was chosen on
//  Update Attendance and is shown read-only here, so a save can never disagree with it.
//
//  The Nomination tab embeds `NominateUsersView`, whose submit inserts attendance rows
//  directly rather than creating a nomination — which is why it needs this screen's status.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct BulkMarkAttendanceView: View {

    @StateObject private var viewModel: AttendanceUsersViewModel
    private let router: AnyRouter

    init(router: AnyRouter, navModel: NavigationViewModel.AttendanceUsersNavModel) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: AttendanceUsersViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            statusHeader

            // A single reachable tab is not a choice — don't draw a bar for it.
            if viewModel.availableTabs.count > 1 { tabBar }

            content

            if viewModel.showsSaveFooter { footer }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Header
private extension BulkMarkAttendanceView {

    /// The status is picked here; the date is not — it arrived with the screen.
    var statusHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(viewModel.attendanceDateText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                CSFieldLabel(title: "Attendance Status", isRequired: true)
                DropDownMenuListViewPkg(
                    viewModel.statusOptions,
                    placeholder: "Select status",
                    selectedOption: viewModel.selectedStatus,
                    isSearchable: false,
                    onSelection: { viewModel.selectStatus($0) }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        // The dropdown expands past its container, so it must draw over the list below.
        .zIndex(1)
    }

    var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.availableTabs, id: \.self) { tab in
                let isSelected = tab == viewModel.activeTab
                Button { viewModel.selectTab(tab) } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSelected ? ColorUtility.primaryColor : .secondary)
                        Rectangle()
                            .fill(isSelected ? ColorUtility.primaryColor : Color.clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Content
private extension BulkMarkAttendanceView {

    @ViewBuilder
    var content: some View {
        switch viewModel.activeTab {
        case .attendance: attendanceTab
        case .nominate:   nominateTab
        }
    }

    var attendanceTab: some View {
        ScrollView {
            AttendanceSectionCard(title: viewModel.mode.sectionTitle, contentPadding: 0) {
                AttendanceListToolbarView(
                    pageSize: viewModel.pageSize,
                    pageSizeChoices: AttendanceUsersViewModel.pageSizeChoices,
                    isAllSelected: viewModel.isAllSelected,
                    selectedText: viewModel.selectedText,
                    onChangePageSize: { viewModel.changePageSize($0) },
                    onToggleSelectAll: { viewModel.toggleSelectAll() }
                )
                // The card no longer insets its content, so the toolbar carries its own.
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                usersList
            }
            .padding(16)
        }
    }

    var usersList: some View {
        AttendanceUsersListView(
            items: viewModel.items,
            isLoading: viewModel.loadingState.isLoading,
            isLoadingMore: viewModel.isLoadingMore,
            isSelectable: viewModel.mode.isSelectable,
            canDelete: viewModel.canDelete,
            emptyMessage: viewModel.mode.emptyMessage,
            emptyIcon: viewModel.mode.emptyIcon,
            isSelected: { viewModel.isSelected($0) },
            onTap: { viewModel.toggle($0) },
            onView: { viewModel.didTapViewUser($0) },
            onDelete: { viewModel.didTapDeleteUser($0) },
            onReachEnd: { viewModel.loadMoreIfNeeded(currentItem: $0) }
        )
    }

    var nominateTab: some View {
        NominateUsersView(
            router: router,
            navModel: NavigationViewModel.NominateUsersNavModel(
                scheduleCode: viewModel.navModel.scheduleCode,
                courseID: viewModel.navModel.courseID,
                moduleID: viewModel.navModel.moduleID,
                onComplete: { viewModel.reloadAfterNomination() },
                // Presence of this context switches the nominate submit to a direct
                // attendance insert. A closure, not a snapshot: the status is picked on this
                // screen and can change while the tab is open. The date is fixed — it came
                // from Update Attendance.
                attendanceContext: {
                    .init(
                        scheduleID: viewModel.navModel.scheduleID,
                        moduleID: viewModel.navModel.moduleID,
                        courseID: viewModel.navModel.courseID,
                        date: viewModel.attendanceDate,
                        statusCode: viewModel.selectedStatus?.valueCode
                    )
                }
            ),
            isEmbedded: true
        )
    }

    var footer: some View {
        HStack {
            CSPrimaryButton(
                title: "Save Attendance",
                isEnabled: viewModel.isSaveEnabled
            ) {
                viewModel.didTapSave()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }
}
