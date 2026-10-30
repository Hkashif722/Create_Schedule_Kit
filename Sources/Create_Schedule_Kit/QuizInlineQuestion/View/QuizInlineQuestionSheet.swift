//
//  QuizInlineQuestionSheet.swift
//  Create_Schedule_Kit
//
//  "Write a new question" sheet: question, answer type, marks, difficulty, learner instruction
//  and 2–5 options with the correct one(s) marked.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct QuizInlineQuestionSheet: View {

    typealias DM = QuizInlineQuestionDataModel

    @StateObject private var viewModel: QuizInlineQuestionViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.QuizInlineQuestionNavModel) {
        _viewModel = StateObject(wrappedValue: QuizInlineQuestionViewModel(router: router, navModel: navModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            CSSheetHeader(
                title: "Write a new question",
                subtitle: "Saved straight into the question bank, so it can be reused in other quizzes and packages.",
                onClose: viewModel.didTapClose
            )
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    questionField
                    answerTypePicker
                    marksAndDifficulty
                    CSTextField(title: "Learner instruction", placeholder: "e.g. Pick one",
                                text: $viewModel.form.learnerInstruction)
                    optionsSection
                    rulesBox
                }
                .padding(20)
            }
            footer
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
    }
}

// MARK: - Sub-views
private extension QuizInlineQuestionSheet {

    var questionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Question", isRequired: true)
            SwiftUIUtility.MultilineTextInputField(
                placeholder: "Type your question here...",
                minHeight: 96,
                cornerRadius: 12,
                borderColor: Color(.systemGray4),
                backgroundColor: Color(.systemBackground),
                maxCharacters: DM.textLimit,
                onTextChanged: { text, _ in viewModel.form.questionText = text }
            )
            HStack {
                Text("Up to \(DM.textLimit) characters")
                Spacer()
                Text(viewModel.characterCountText)
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
    }

    var answerTypePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Answer type")
            CSSegmentedControl(
                options: ScheduleQuizDataModel.OptionType.allCases,
                title: { $0.title },
                selection: Binding(
                    get: { viewModel.form.optionType },
                    set: { viewModel.didSelectOptionType($0) }
                )
            )
        }
    }

    var marksAndDifficulty: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                CSTextField(title: "Marks", isRequired: true, placeholder: "1",
                            text: $viewModel.form.marksText, keyboardType: .numberPad)
                Text("1–25")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                CSFieldLabel(title: "Difficulty")
                Menu {
                    ForEach(ScheduleQuizDataModel.Difficulty.allCases) { level in
                        Button(level.rawValue) { viewModel.form.difficulty = level }
                    }
                } label: {
                    HStack {
                        Text(viewModel.form.difficulty.rawValue)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .accessibilityLabel("Difficulty, \(viewModel.form.difficulty.rawValue)")
            }
        }
    }

    var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CSFieldLabel(title: "Answer options", isRequired: true)
                Spacer()
                Text(viewModel.form.optionType == .single ? "Tap to mark the correct one" : "Tick every correct one")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            ForEach(Array(viewModel.form.options.enumerated()), id: \.element.id) { index, option in
                optionRow(option, index: index)
            }

            if viewModel.form.canAddOption {
                Button(action: viewModel.didTapAddOption) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add option")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(CSTheme.primaryColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(CSTheme.primaryColor.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    func optionRow(_ option: DM.OptionRow, index: Int) -> some View {
        let letter = DM.Form.optionLetter(at: index)
        let isSingle = viewModel.form.optionType == .single
        let correctSymbol = isSingle ? "checkmark.circle.fill" : "checkmark.square.fill"
        let emptySymbol = isSingle ? "circle" : "square"
        return HStack(spacing: 10) {
            Button { viewModel.didTapCorrect(option.id) } label: {
                Image(systemName: option.isCorrect ? correctSymbol : emptySymbol)
                    .font(.system(size: 22))
                    .foregroundColor(option.isCorrect ? .green : Color(.systemGray3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark option \(letter) correct")
            .accessibilityAddTraits(option.isCorrect ? .isSelected : [])

            Text(letter)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            TextField("Option \(letter)", text: optionTextBinding(option.id))
                .font(.system(size: 15, weight: .medium))

            SwiftUIUtility.CircleCloseButton(
                foregroundColor: viewModel.form.canRemoveOption ? .secondary : Color(.systemGray4),
                backgroundColor: .clear,
                size: 40,
                action: { viewModel.didTapRemoveOption(option.id) }
            )
            .disabled(!viewModel.form.canRemoveOption)
            .accessibilityLabel("Remove option \(letter)")
        }
        .padding(.leading, 2)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(option.isCorrect ? Color.green.opacity(0.08) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(option.isCorrect ? Color.green.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }

    func optionTextBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.form.options.first { $0.id == id }?.text ?? "" },
            set: { newValue in
                guard let index = viewModel.form.options.firstIndex(where: { $0.id == id }) else { return }
                viewModel.form.options[index].text = newValue
            }
        )
    }

    var rulesBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A question can't be saved when")
                .font(.system(size: 14, weight: .bold))
            ForEach([
                "there are fewer than 2 or more than 5 options, or one is empty",
                "two options have the same text",
                "no option is correct, or single selection has more than one"
            ], id: \.self) { rule in
                Text("• \(rule)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    var footer: some View {
        HStack(spacing: 12) {
            CSSecondaryButton(title: "Cancel", action: viewModel.didTapClose)
            CSPrimaryButton(title: "Save to bank & add", isEnabled: !viewModel.isSaving, action: viewModel.didTapSave)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    QuizInlineQuestionSheet(router: router, navModel: .init(onSaved: { _ in }))
}
