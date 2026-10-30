//
//  QuizBankPickerSheet.swift
//  Create_Schedule_Kit
//
//  "Pick from question bank" sheet: search, Difficulty + Option type filters, multi-select.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct QuizBankPickerSheet: View {

    @StateObject private var viewModel: QuizBankPickerViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.QuizBankPickerNavModel) {
        _viewModel = StateObject(wrappedValue: QuizBankPickerViewModel(router: router, navModel: navModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            CSSheetHeader(title: "Pick from question bank", subtitle: viewModel.countText, onClose: viewModel.didTapClose)
            filters
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
private extension QuizBankPickerSheet {

    typealias DM = ScheduleQuizDataModel

    var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            CSSearchField(
                text: $viewModel.searchText,
                placeholder: "Search questions",
                isSearching: viewModel.isSearching,
                onTextChanged: viewModel.onSearchChanged
            )
            HStack(spacing: 10) {
                filterMenu(title: "Difficulty", value: viewModel.difficultyTitle) {
                    Button("All") { viewModel.selectDifficulty(nil) }
                    ForEach(DM.Difficulty.allCases) { level in
                        Button(level.rawValue) { viewModel.selectDifficulty(level) }
                    }
                }
                filterMenu(title: "Option type", value: viewModel.optionTypeTitle) {
                    Button("All") { viewModel.selectOptionType(nil) }
                    ForEach(DM.OptionType.allCases) { type in
                        Button(type.title) { viewModel.selectOptionType(type) }
                    }
                }
            }
            Text("Only active, objective questions are shown.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    func filterMenu<Items: View>(title: String, value: String, @ViewBuilder items: () -> Items) -> some View {
        Menu {
            items()
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
        }
        .accessibilityLabel("\(title), \(value)")
    }

    @ViewBuilder
    var content: some View {
        if viewModel.items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                if viewModel.loadingState.isLoading || viewModel.isSearching {
                    ProgressView()
                } else {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("No questions found")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.items) { question in
                        QuizBankQuestionRow(
                            question: question,
                            isSelected: viewModel.isSelected(question),
                            isBlocked: viewModel.isBlocked(question),
                            onTap: { viewModel.toggle(question) }
                        )
                        .onAppear { viewModel.loadMoreIfNeeded(currentItem: question) }
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
            CSPrimaryButton(title: viewModel.addTitle, isEnabled: viewModel.canAdd, action: viewModel.didTapAdd)
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
    QuizBankPickerSheet(router: router, navModel: .init(quizID: 32, blockedIDs: [517], onAdd: { _ in }))
}
