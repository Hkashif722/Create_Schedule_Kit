//
//  QuizPackagePickerSheet.swift
//  Create_Schedule_Kit
//
//  "Add question package" sheet: search, multi-select rows, running "+questions · +marks".
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct QuizPackagePickerSheet: View {

    @StateObject private var viewModel: QuizPackagePickerViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.QuizPackagePickerNavModel) {
        _viewModel = StateObject(wrappedValue: QuizPackagePickerViewModel(router: router, navModel: navModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            CSSheetHeader(title: "Add question package", subtitle: viewModel.countText, onClose: viewModel.didTapClose)
            CSSearchField(
                text: $viewModel.searchText,
                placeholder: "Search package name or description",
                isSearching: viewModel.isSearching,
                onTextChanged: viewModel.onSearchChanged
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            Divider()
            content
            footer
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.loadFirstPage() }
    }
}

// MARK: - Sub-views
private extension QuizPackagePickerSheet {

    @ViewBuilder
    var content: some View {
        if viewModel.items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                if viewModel.loadingState.isLoading || viewModel.isSearching {
                    ProgressView()
                } else {
                    Image(systemName: "archivebox")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("No packages found")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.items) { package in
                        QuizPackagePickerRow(
                            package: package,
                            isSelected: viewModel.isSelected(package),
                            isAttached: viewModel.isAttached(package),
                            onTap: { viewModel.toggle(package) }
                        )
                        .onAppear { viewModel.loadMoreIfNeeded(currentItem: package) }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView().padding(.vertical, 12)
                    }
                }
                .padding(20)
            }
        }
    }

    var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.summaryText)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                CSSecondaryButton(title: "Cancel", action: viewModel.didTapClose)
                CSPrimaryButton(title: viewModel.addTitle, isEnabled: viewModel.canAdd, action: viewModel.didTapAdd)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    QuizPackagePickerSheet(router: router, navModel: .init(attachedIDs: [1], onAdd: { _ in }))
}
