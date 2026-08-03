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
            Text("Scheduler")
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
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search schedules…", text: $viewModel.searchText)
                    .font(.system(size: 15))
                    .onChange(of: viewModel.searchText) { newValue in
                        viewModel.onSearchChanged(newValue)
                    }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Advanced filter — not yet designed. Placeholder affordance.
            Button {
                // TODO: advanced filter sheet (pending design).
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorUtility.primaryColor)
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    var content: some View {
        if viewModel.loadingState.isLoading && viewModel.items.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.displayItems.isEmpty {
            emptyState
        } else {
            list
        }
    }

    var list: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.displayItems) { schedule in
                    ScheduleCardView(
                        schedule: schedule,
                        onViewDetails: { viewModel.didTapViewDetails(schedule) },
                        onAttendance: { viewModel.didTapAttendance(schedule) },
                        onEdit: { viewModel.didTapEdit(schedule) }
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
            Text("No schedules found")
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
