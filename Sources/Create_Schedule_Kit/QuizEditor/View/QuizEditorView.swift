//
//  QuizEditorView.swift
//  Create_Schedule_Kit
//
//  One Pre/Post quiz: settings summary, Add package / From bank / Write new, the attached
//  package cards and directly added questions, and a sticky totals + Save bar.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct QuizEditorView: View {

    @StateObject private var viewModel: QuizEditorViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.QuizEditorNavModel) {
        _viewModel = StateObject(wrappedValue: QuizEditorViewModel(router: router, navModel: navModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let draft = viewModel.draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if viewModel.isLocked {
                            CSInfoBanner(
                                style: .warning,
                                message: "Learners have started this quiz. Questions, marks, pass % and duration can no longer change."
                            )
                        }
                        QuizSettingsSummaryCard(settings: draft.settings, onEdit: viewModel.didTapEditSettings)
                        questionsHeader
                        if let banner = viewModel.saveBanner {
                            saveBannerView(banner)
                        }
                        questionLists(draft)
                    }
                    .padding()
                    .animation(.default, value: viewModel.saveBanner)
                }
                footer
            } else if viewModel.loadFailed {
                loadFailedView
            } else {
                Spacer()
            }
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension QuizEditorView {

    var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: viewModel.didTapBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.headerTitle)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                statusChips
            }
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
    }

    /// Two rows: kind + publish state + lock always fit at 375pt; attempts and the unsaved
    /// marker drop to their own line instead of pushing the row off screen.
    var statusChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                CSQuizKindBadge(kind: viewModel.kind)
                if viewModel.summary != nil {
                    if viewModel.isPublished {
                        CSStatusChip(title: "Published", tint: .green)
                    } else {
                        CSStatusChip(title: "Draft", tint: .orange)
                    }
                }
                if viewModel.isLocked {
                    CSStatusChip(title: "Locked", systemImage: "lock.fill", tint: .gray)
                }
            }
            if viewModel.attemptsText != nil || viewModel.hasUnsavedChanges {
                HStack(spacing: 6) {
                    if let attempts = viewModel.attemptsText {
                        Text(attempts).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    if viewModel.hasUnsavedChanges {
                        CSStatusChip(title: "Unsaved changes", tint: .secondary)
                    }
                }
            }
        }
    }

    var questionsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Questions")
                .font(.system(size: 18, weight: .bold))
            HStack(spacing: 10) {
                QuizSourceTile(title: "Add package", systemImage: "archivebox",
                               isEnabled: !viewModel.isLocked, action: viewModel.didTapAddPackage)
                QuizSourceTile(title: "From bank", systemImage: "list.bullet.rectangle",
                               isEnabled: !viewModel.isLocked, action: viewModel.didTapPickFromBank)
                QuizSourceTile(title: "Write new", systemImage: "pencil",
                               isEnabled: !viewModel.isLocked, action: viewModel.didTapWriteNew)
            }
        }
    }

    func saveBannerView(_ banner: QuizEditorViewModel.SaveBanner) -> some View {
        CSInfoBanner(
            style: .success,
            title: banner.title,
            message: banner.messages.isEmpty ? "Learners will see these questions." : banner.messages.joined(separator: "\n")
        )
    }

    @ViewBuilder
    func questionLists(_ draft: QuizDraft) -> some View {
        if draft.isEmpty {
            Text("No questions yet.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        }
        ForEach(Array(draft.packages.enumerated()), id: \.element.id) { offset, package in
            QuizPackageCardView(
                package: package,
                startIndex: viewModel.startIndex(ofPackageAt: offset),
                isExpanded: viewModel.expandedPackageIDs.contains(package.id),
                canRemove: !viewModel.isLocked,
                onToggle: { viewModel.toggleExpanded(package.id) },
                onRemove: { viewModel.didTapRemovePackage(package.id) }
            )
        }
        if !draft.directQuestions.isEmpty {
            QuizDirectQuestionsCard(
                questions: draft.directQuestions,
                startIndex: viewModel.directStartIndex,
                canRemove: !viewModel.isLocked,
                onRemove: viewModel.didTapRemoveQuestion
            )
        }
    }

    var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.totalsText)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            CSPrimaryButton(title: "Save", isEnabled: viewModel.canSave, action: viewModel.didTapSave)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    var loadFailedView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Couldn't load this quiz")
                .font(.system(size: 16, weight: .semibold))
            CSSecondaryButton(title: "Retry", systemImage: "arrow.clockwise", action: viewModel.didTapRetry)
                .frame(maxWidth: 200)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    QuizEditorView(
        router: router,
        navModel: .init(quizID: 97, kind: .pre, onChanged: {}, isOtherSlotEmpty: { true }, onAddOtherQuiz: {})
    )
}
