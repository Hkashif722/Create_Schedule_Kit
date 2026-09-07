//
//  ScheduleUsersView.swift
//  Create_Schedule_Kit
//
//  The waiting list and the availability roster. One screen: `mode` on the view model
//  decides the title, the route behind it and the empty-state copy.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct ScheduleUsersView: View {

    @StateObject private var viewModel: ScheduleUsersViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.ScheduleUsersNavModel) {
        _viewModel = StateObject(
            wrappedValue: ScheduleUsersViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            CSSearchField(
                text: $viewModel.searchText,
                placeholder: viewModel.searchPlaceholder,
                isSearching: viewModel.isSearching,
                onTextChanged: { viewModel.onSearchChanged($0) }
            )
            .padding(.horizontal)
            .padding(.top, 12)

            content
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        // Same custom bar as Schedule Details, which pushes this screen: that screen hides
        // the system bar, and on iOS 15 the hidden state carries over to what it pushes.
        .navigationBarHidden(true)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Content
private extension ScheduleUsersView {

    var header: some View {
        ZStack {
            Text(viewModel.title)
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
            }
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
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            list
        }
    }

    var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.sectionTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.items) { user in
                        ScheduleUserRowView(user: user)
                            .onAppear { viewModel.loadMoreIfNeeded(currentItem: user) }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView().padding(.vertical, 16)
                    }
                }
            }
            .padding()
        }
    }

    /// The section caption stays pinned at the top so the screen reads the same whether or
    /// not it has rows; the message sits above centre, as the design has it.
    var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.mode.sectionTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 16)

            Spacer()

            VStack(spacing: 10) {
                Image(systemName: viewModel.mode.emptyIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(viewModel.mode.emptyMessage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
