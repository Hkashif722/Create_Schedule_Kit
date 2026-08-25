//
//  CancelScheduleView.swift
//  Create_Schedule_Kit
//
//  Cancel Schedule bottom sheet, opened from a schedule card. Shows the schedule being cancelled,
//  collects a mandatory reason, and warns first when users are already nominated.
//
//  Presented via `AppNavigationDestination.cancelSchedule` → `showFullSheetWithDragGesture`, so on
//  iOS 16+ the drag indicator comes from the router and this view supplies only its own title row.
//  On iOS 15 that helper falls back to a plain `.sheet` with no indicator, which is why the title
//  row carries its own close button rather than relying on the drag affordance.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct CancelScheduleView: View {

    @StateObject private var viewModel: CancelScheduleViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.CancelScheduleNavModel) {
        _viewModel = StateObject(
            wrappedValue: CancelScheduleViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.hasNominations {
                        CancelScheduleWarningBanner(
                            message: "Users are already nominated or requested for the schedule, are you sure to cancel this schedule?"
                        )
                    }

                    Divider()
                    scheduleSummary
                    Divider()
                    reasonField
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
                // The banner arrives a moment after the sheet opens, so animate the reflow
                // instead of letting the content jump.
                .animation(.default, value: viewModel.hasNominations)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        // Tap-to-dismiss the keyboard. Load-bearing on iOS 15: the reason editor's "Done"
        // toolbar is iOS 16+, TextEditor swallows Return, and both CTAs sit below the field —
        // without this an iOS 15 user cannot reach them.
        .onTapGesture { dismissKeyboard() }
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension CancelScheduleView {

    func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    var header: some View {
        HStack {
            Text("Cancel Schedule")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            Spacer(minLength: 8)

            Button { viewModel.didTapClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    var scheduleSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            summaryRow(caption: "SCHEDULE CODE", value: viewModel.scheduleCode)
            summaryRow(caption: "MODULE NAME", value: viewModel.moduleName)
        }
    }

    func summaryRow(caption: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The editor keeps its own text state and reports out through `onTextChanged`; the view model
    /// holds it only to validate. `maxCharacters` enforces the 300 cap inside the component.
    var reasonField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Reason for cancellation", isRequired: true)

            SwiftUIUtility.MultilineTextInputField(
                placeholder: "State why this schedule is being cancelled",
                minHeight: 110,
                cornerRadius: 12,
                borderColor: viewModel.showsReasonWarningBorder
                    ? ColorUtility.primaryColor
                    : Color(.systemGray4),
                backgroundColor: Color(.systemBackground),
                maxCharacters: CancelScheduleViewModel.reasonLimit,
                onTextChanged: { text, _ in viewModel.reason = text }
            )

            HStack(alignment: .top, spacing: 8) {
                Text(viewModel.helperText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer(minLength: 8)
                Text(viewModel.characterCountText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    var actions: some View {
        VStack(spacing: 4) {
            CSPrimaryButton(title: "Cancel Schedule", isEnabled: viewModel.isSubmitEnabled) {
                viewModel.didTapCancelSchedule()
            }
            CSPlainTextButton(title: "Keep Schedule") {
                viewModel.didTapKeep()
            }
        }
        .padding(.top, 4)
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
    return CancelScheduleView(
        router: router,
        navModel: NavigationViewModel.CancelScheduleNavModel(
            scheduleID: 4127,
            scheduleCode: "SC8539",
            moduleName: "19965_Team Building Course",
            onCancelled: {}
        )
    )
}
