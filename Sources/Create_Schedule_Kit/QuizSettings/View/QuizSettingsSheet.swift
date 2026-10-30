//
//  QuizSettingsSheet.swift
//  Create_Schedule_Kit
//
//  "Create pre quiz" / "Quiz settings" sheet: title, instructions, pass %, duration and the
//  show-result switch.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct QuizSettingsSheet: View {

    @StateObject private var viewModel: QuizSettingsViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.QuizSettingsNavModel) {
        _viewModel = StateObject(wrappedValue: QuizSettingsViewModel(router: router, navModel: navModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            CSSheetHeader(title: viewModel.title, onClose: viewModel.didTapCancel)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.isScoringLocked {
                        CSInfoBanner(
                            style: .warning,
                            message: "Learners have started this quiz. Pass % and duration can no longer change."
                        )
                    }
                    titleField
                    instructionsField
                    scoringFields
                    showResultToggle
                }
                .padding(20)
            }
            footer
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onDisappear { viewModel.onDisappear() }
    }
}

// MARK: - Sub-views
private extension QuizSettingsSheet {

    var titleField: some View {
        CSTextField(title: "Title", isRequired: true, placeholder: "Quiz title", text: $viewModel.form.title)
    }

    var instructionsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Instructions")
            SwiftUIUtility.MultilineTextInputField(
                initialText: viewModel.form.instructions,
                placeholder: "Shown to learners before they start",
                minHeight: 90,
                cornerRadius: 12,
                borderColor: Color(.systemGray4),
                backgroundColor: Color(.systemBackground),
                maxCharacters: 1000,
                onTextChanged: { text, _ in viewModel.form.instructions = text }
            )
        }
    }

    var scoringFields: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                CSTextField(title: "Pass %", placeholder: "e.g. 60", text: $viewModel.form.passText,
                            isReadOnly: viewModel.isScoringLocked, keyboardType: .decimalPad)
                hint("0–100. Blank = no pass/fail.")
            }
            VStack(alignment: .leading, spacing: 4) {
                CSTextField(title: "Duration (min)", placeholder: "e.g. 30", text: $viewModel.form.durationText,
                            isReadOnly: viewModel.isScoringLocked, keyboardType: .numberPad)
                hint("1–1440. Blank = untimed.")
            }
        }
    }

    var showResultToggle: some View {
        Toggle(isOn: $viewModel.form.showResultToLearner) {
            Text("Show result to learner after submit")
                .font(.system(size: 15, weight: .medium))
        }
        .toggleStyle(SwitchToggleStyle(tint: CSTheme.primaryColor))
        .frame(minHeight: 44)
    }

    var footer: some View {
        HStack(spacing: 12) {
            CSSecondaryButton(title: "Cancel", action: viewModel.didTapCancel)
            CSPrimaryButton(title: viewModel.primaryTitle, isEnabled: !viewModel.isSubmitting,
                            action: viewModel.didTapSubmit)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    QuizSettingsSheet(
        router: router,
        navModel: .init(
            kind: .pre,
            mode: .create(scheduleID: 4826),
            initial: .defaults(kind: .pre, displayName: "Test ILT006"),
            isLocked: false,
            onDone: { _ in },
            onCancel: {}
        )
    )
}
