//
//  FeedbackModulePickerSheet.swift
//  Create_Schedule_Kit
//
//  Bottom sheet to multi-select feedback modules for Step 3. Modules are fetched server-side
//  (paginated, searchable) via FeedbackModulePickerViewModel.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct FeedbackModulePickerSheet: View {

    @StateObject private var viewModel: FeedbackModulePickerViewModel
    private let router: AnyRouter

    private let teal = Color.teal

    init(router: AnyRouter, navModel: NavigationViewModel.FeedbackPickerNavModel) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: FeedbackModulePickerViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()

            content

            CSPrimaryButton(
                title: viewModel.selectedID == nil ? "Select a feedback module" : "Add feedback module",
                isEnabled: viewModel.selectedID != nil
            ) {
                viewModel.save()
            }
            .padding()
        }
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.loadFirstPage() }
    }

    @ViewBuilder
    private var content: some View {
        if (viewModel.loadingState.isLoading || viewModel.isSearching) && viewModel.items.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.items) { module in
                    row(module)
                    Divider().padding(.leading, 64)
                    Color.clear.frame(height: 1)
                        .onAppear { viewModel.loadMoreIfNeeded(currentItem: module) }
                }
                if viewModel.isLoadingMore {
                    ProgressView().padding(.vertical, 16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bubble.left")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No feedback modules found")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose feedback module")
                    .font(.system(size: 18, weight: .bold))
                Text("\(viewModel.totalRecords) modules · tap to select")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { router.dismissScreen() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search module…", text: $viewModel.searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .onChange(of: viewModel.searchText) { newValue in
                    viewModel.onSearchChanged(newValue)
                }
            // Searching reports itself here rather than behind a full-screen overlay.
            if viewModel.isSearching {
                ProgressView().scaleEffect(0.8)
            } else if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func row(_ module: ScheduleFeedbackDataModel.FeedbackModule) -> some View {
        let isSelected = viewModel.selectedID == module.id
        return Button {
            viewModel.select(module)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(teal.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "bubble.left").font(.system(size: 15, weight: .semibold)).foregroundColor(teal))
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.title).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                    Text(module.subtitle).font(.system(size: 12.5)).foregroundColor(.secondary)
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? ColorUtility.primaryColor : Color(.systemGray3), lineWidth: 1.8)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(ColorUtility.primaryColor).frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
