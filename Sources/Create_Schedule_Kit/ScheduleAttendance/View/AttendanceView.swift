//
//  AttendanceView.swift
//  Create_Schedule_Kit
//
//  "Update Attendance" screen, pushed from a schedule card's Attendance action. An
//  Attendance / Nominate tab bar sits above the content; the Attendance tab shows the
//  schedule info, a date + status picker, and a selectable, paginated user list. Save
//  marks attendance for the selected users.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct AttendanceView: View {

    @StateObject private var viewModel: AttendanceViewModel
    private let router: AnyRouter

    init(router: AnyRouter, navModel: NavigationViewModel.AttendanceNavModel) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: AttendanceViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // A single reachable tab is not a choice — don't draw a bar for it.
            if viewModel.availableTabs.count > 1 { tabBar }
            content
            if viewModel.showsSaveFooter {
                footer
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Update Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Tab bar
private extension AttendanceView {

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
private extension AttendanceView {

    @ViewBuilder
    var content: some View {
        switch viewModel.activeTab {
        case .attendance: attendanceTab
        case .nominate:   nominateTab
        }
    }

    var attendanceTab: some View {
        ScrollView {
            // Strictly-decreasing zIndex top→bottom so the status dropdown, which expands
            // as an overlay past its card, draws above the user list beneath it.
            VStack(spacing: 16) {
                infoCard.zIndex(3)
                formCard.zIndex(2)
                usersCard.zIndex(1)
            }
            .padding(16)
        }
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
                // attendance insert. No cycle: the attendance VM never holds the nominate one.
                attendanceContext: {
                    .init(
                        scheduleID: viewModel.navModel.scheduleID,
                        moduleID: viewModel.navModel.moduleID,
                        courseID: viewModel.navModel.courseID,
                        date: viewModel.selectedDate,
                        statusCode: viewModel.selectedStatus?.valueCode
                    )
                }
            ),
            isEmbedded: true
        )
    }

    // MARK: Card 1 — read-only schedule info

    var infoCard: some View {
        card {
            VStack(spacing: 14) {
                CSTextField(title: "Course Name", placeholder: "-",
                            text: .constant(viewModel.navModel.courseName), isReadOnly: true)
                CSTextField(title: "Module Name", placeholder: "-",
                            text: .constant(viewModel.navModel.moduleName), isReadOnly: true)
                CSTextField(title: "Schedule Code", placeholder: "-",
                            text: .constant(viewModel.navModel.scheduleCode), isReadOnly: true)
            }
        }
    }

    // MARK: Card 2 — date + status

    var formCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                CSTextField(title: "Schedule Details", placeholder: "-",
                            text: .constant(viewModel.scheduleDateRangeText), isReadOnly: true)

                CSRequiredDateField(
                    router: router,
                    title: "Attendance for the Date",
                    placeHolder: "Select date",
                    minimumDate: viewModel.datePickerMinimum,
                    maximumDate: viewModel.datePickerMaximum,
                    onDateSelected: { viewModel.didSelectDate($0) }
                )

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
        }
    }

    // MARK: Card 3 — user list

    var usersCard: some View {
        card {
            VStack(spacing: 0) {
                listHeader
                Divider().padding(.vertical, 12)
                userList
                Divider().padding(.top, 12)
                listFooter
            }
        }
    }

    var listHeader: some View {
        HStack(spacing: 12) {
            Text("Show")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            pageSizeMenu
            Spacer()
            Button { viewModel.toggleSelectAll() } label: {
                HStack(spacing: 8) {
                    selectionBox(isOn: viewModel.isAllSelected)
                    Text("Select all")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    var pageSizeMenu: some View {
        Menu {
            ForEach(AttendanceViewModel.pageSizeChoices, id: \.self) { size in
                Button("\(size)") { viewModel.changePageSize(size) }
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(viewModel.pageSize)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    var userList: some View {
        if viewModel.loadingState.isLoading && viewModel.items.isEmpty {
            ProgressView().padding(.vertical, 24)
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.items) { user in
                    AttendanceUserRowView(
                        user: user,
                        isSelected: viewModel.isSelected(user),
                        canDelete: viewModel.canDelete,
                        onTap: { viewModel.toggle(user) },
                        onView: { viewModel.didTapViewUser(user) },
                        onDelete: { viewModel.didTapDeleteUser(user) }
                    )
                    .onAppear { viewModel.loadMoreIfNeeded(currentItem: user) }
                    if user.id != viewModel.items.last?.id {
                        Divider().padding(.leading, 82)
                    }
                }
                if viewModel.isLoadingMore {
                    ProgressView().padding(.vertical, 16)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No users found")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    var listFooter: some View {
        HStack {
            Text(viewModel.totalText)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(viewModel.selectedText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorUtility.primaryColor)
        }
    }

    // MARK: Footer CTA

    var footer: some View {
        CSPrimaryButton(title: "Save", isEnabled: viewModel.isSaveEnabled) {
            viewModel.didTapSave()
        }
        .padding()
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Shared helpers
private extension AttendanceView {

    func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
    }

    func selectionBox(isOn: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(isOn ? ColorUtility.primaryColor : Color(.systemGray3), lineWidth: 1.8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? ColorUtility.primaryColor : Color.clear)
            )
            .frame(width: 24, height: 24)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(isOn ? 1 : 0)
            )
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    SwiftUtilityEnvironment.configure(
        SwiftUtilityConfig(
            encryptionDecryptionKey: "preview-key",
            isBlobEnabled: true,
            orgCode: "preview",
            configurableDate: "dd-MM-yyyy",
            baseURL: "",
            lxpOPath: "",
            lxpBlobPath: "",
            lxpBlobPath1: ""
        )
    )
    return AttendanceView(
        router: router,
        navModel: NavigationViewModel.AttendanceNavModel(
            scheduleID: 3787, courseID: 56288, moduleID: 42182,
            courseName: "absent flow import",
            moduleName: "18387_absent flow import",
            scheduleCode: "SC6649",
            dateRangeText: "Jul 02, 2026 – Jul 02, 2026"
        )
    )
}
