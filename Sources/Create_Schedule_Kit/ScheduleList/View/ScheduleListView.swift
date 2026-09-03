//
//  ScheduleListView.swift
//  Create_Schedule_Kit
//
//  Scheduler landing screen — the package's dashboard entry point. Lists schedules with
//  Upcoming/Completed tabs and search; "+ New" launches the create-schedule wizard.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct ScheduleListView: View {

    @StateObject private var viewModel: ScheduleListViewModel
    private let router: AnyRouter

    init(router: AnyRouter, onFinish: ((CreateScheduleKitEvent) -> Void)? = nil) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: ScheduleListViewModel(router: router, onFinish: onFinish)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScheduleTabBarView(
                selection: Binding(
                    get: { viewModel.selectedTab },
                    set: { viewModel.selectTab($0) }
                )
            )
            filterRow.zIndex(1)
            searchBar
            content
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension ScheduleListView {

    var header: some View {
        ZStack {
            Text("ILT Schedule")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Button { viewModel.didTapBack() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                if viewModel.canCreateSchedule {
                    Button { viewModel.didTapNew() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                            Text("New").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(ColorUtility.primaryColor.getDynamicTextColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(ColorUtility.primaryColor))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    /// Which column the search box filters on — mirrors the web client's "Filter" dropdown.
    var filterRow: some View {
        HStack(spacing: 10) {
            DropDownMenuListViewPkg(
                ScheduleListDataModel.FilterColumn.allCases,
                placeholder: "Select",
                selectedOption: viewModel.filterColumn,
                isSearchable: false,
                controlHeight: 44,
                maxContentHeight: 300,
                font: .system(size: 15),
                onSelection: { viewModel.selectFilterColumn($0) }
            )
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .background(Color(.systemBackground))
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField(viewModel.searchPlaceholder, text: $viewModel.searchText)
                    .font(.system(size: 15))
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) { newValue in
                        viewModel.onSearchChanged(newValue)
                    }
                // Searching reports itself here rather than behind a full-screen overlay.
                if viewModel.isSearching {
                    ProgressView().scaleEffect(0.8)
                } else if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    var content: some View {
        if viewModel.loadingState.isLoading && viewModel.items.isEmpty {
            spinner
        } else if viewModel.displayItems.isEmpty {
            // The tab can still be filling itself from later pages, and a search reload empties
            // the rows before the results land — don't claim it's empty yet in either case.
            if viewModel.isFillingTab || viewModel.isSearching { spinner } else { emptyState }
        } else {
            list
        }
    }

    var spinner: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var list: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.displayItems) { schedule in
                    ScheduleCardView(
                        schedule: schedule,
                        participants: viewModel.participantCount(for: schedule),
                        onViewDetails: { viewModel.didTapViewDetails(schedule) },
                        onAttendance: { viewModel.didTapAttendance(schedule) },
                        onEdit: { viewModel.didTapEdit(schedule) },
                        onCancel: { viewModel.didTapCancel(schedule) },
                        canEdit: viewModel.canEditSchedule,
                        canCancel: viewModel.canCancelSchedule
                    )
                    .onAppear { viewModel.loadMoreIfNeeded(currentItem: schedule) }
                }
                if viewModel.isLoadingMore {
                    ProgressView().padding(.vertical, 16)
                }
            }
            .padding()
        }
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No \(viewModel.selectedTab.title.lowercased()) schedules")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
    return ScheduleListView(router: router)
}
