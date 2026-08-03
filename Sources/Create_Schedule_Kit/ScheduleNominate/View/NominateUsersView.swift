//
//  NominateUsersView.swift
//  Create_Schedule_Kit
//
//  Post-create "Nominate Users" bottom sheet. Presented after a schedule is created
//  (via the nomination confirmation alert). Lets the creator search (column-scoped
//  typeahead), multi-select users, and submit nominations.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct NominateUsersView: View {

    @StateObject private var viewModel: NominateUsersViewModel
    private let router: AnyRouter
    /// When embedded inside another screen (e.g. the Attendance tab), the navigation
    /// chrome (title + close button) is dropped so the host screen keeps its own.
    private let isEmbedded: Bool

    init(router: AnyRouter,
         navModel: NavigationViewModel.NominateUsersNavModel,
         isEmbedded: Bool = false) {
        self.router = router
        self.isEmbedded = isEmbedded
        _viewModel = StateObject(
            wrappedValue: NominateUsersViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        Group {
            if isEmbedded {
                mainStack
            } else {
                mainStack
                    .navigationTitle("Nominate Users")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if #available(iOS 26.0, *) {
                                Button(role: .close) { viewModel.didTapCancel() }
                            } else {
                                Button { viewModel.didTapCancel() } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
            }
        }
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }

    private var mainStack: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                columnRow
                    .zIndex(1)
                searchSection
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .zIndex(1)

            Divider().padding(.top, 12)
            selectAllRow
            Divider()

            content

            footer
        }
    }
}

// MARK: - Sub-views
private extension NominateUsersView {

    var columnRow: some View {
        HStack(spacing: 10) {
            DropDownMenuListViewPkg(
                viewModel.columns,
                placeholder: "Select",
                selectedOption: viewModel.selectedColumn,
                isSearchable: false,
                onSelection: { viewModel.selectColumn($0) }
            )

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
    }

    var searchSection: some View {
        DropDownMenuListViewPkg(
            viewModel.typeaheadResults,
            placeholder: "Search name, ID, email…",
            isSearchable: true,
            onSearchTextChange: { viewModel.onSearchChanged($0) },
            onSelection: { viewModel.selectSuggestion($0) }
        )
    }

    var selectAllRow: some View {
        Button { viewModel.toggleSelectAll() } label: {
            HStack(spacing: 12) {
                selectionBox(isOn: viewModel.isAllSelected)
                Text("Select all")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text(viewModel.usersCountText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            LazyVStack(spacing: 0) {
                ForEach(viewModel.items) { user in
                    NominateUserRowView(
                        user: user,
                        isSelected: viewModel.isSelected(user),
                        onTap: { viewModel.toggle(user) }
                    )
                    .onAppear { viewModel.loadMoreIfNeeded(currentItem: user) }
                    Divider().padding(.leading, 82)
                }
                if viewModel.isLoadingMore {
                    ProgressView().padding(.vertical, 16)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "person.2")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No users found")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var footer: some View {
        HStack(spacing: 12) {
            CSSecondaryButton(title: "Cancel") { viewModel.didTapCancel() }
            CSPrimaryButton(
                title: viewModel.nominateButtonTitle,
                isEnabled: viewModel.isNominateEnabled
            ) {
                viewModel.didTapNominate()
            }
        }
        .padding()
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
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
    return NominateUsersView(
        router: router,
        navModel: NavigationViewModel.NominateUsersNavModel(
            scheduleCode: "SC6630", courseID: 123, moduleID: 456, onComplete: {}
        )
    )
}
