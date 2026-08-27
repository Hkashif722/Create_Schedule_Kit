//
//  CreateTrainerView.swift
//  Create_Schedule_Kit
//
//  Create New Trainer bottom sheet, opened from Step 2's Trainer field when Trainer Type is
//  External. Collects name / email / mobile, then hands the created account back to Step 2.
//
//  Presented via `AppNavigationDestination.createTrainer` → `showFullSheetWithDragGesture`
//  rather than a resizable sheet: three text fields plus both CTAs sit under the keyboard at
//  a medium detent. Same reasoning as `CancelScheduleView`, which is why this view also
//  carries its own close button — the router's drag indicator is iOS 16+ only.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct CreateTrainerView: View {

    @StateObject private var viewModel: CreateTrainerViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.CreateTrainerNavModel) {
        _viewModel = StateObject(
            wrappedValue: CreateTrainerViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameField
                    emailField
                    mobileField
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
    }
}

// MARK: - Sub-views
private extension CreateTrainerView {

    var header: some View {
        HStack(alignment: .center) {
            Text("Create New Trainer")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Spacer(minLength: 8)

            Button { viewModel.didTapCancel() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    var nameField: some View {
        CreateTrainerFormField(
            title: "User name",
            placeholder: "Enter trainer name",
            text: $viewModel.form.name,
            textContentType: .name,
            errorMessage: nameError
        )
    }

    var emailField: some View {
        CreateTrainerFormField(
            title: "Email id",
            placeholder: "Enter email address",
            text: $viewModel.form.email,
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            autocapitalization: .never,
            errorMessage: emailError
        )
    }

    var mobileField: some View {
        CreateTrainerFormField(
            title: "Mobile number",
            placeholder: "Enter mobile number",
            text: Binding(
                get: { viewModel.form.mobile },
                set: { viewModel.onMobileChanged($0) }
            ),
            keyboardType: .numberPad,
            textContentType: .telephoneNumber,
            autocapitalization: .never,
            errorMessage: mobileError
        )
    }

    var actions: some View {
        VStack(spacing: 12) {
            CSPrimaryButton(title: "Add Trainer", isEnabled: viewModel.isAddEnabled) {
                viewModel.didTapAddTrainer()
            }
            CSSecondaryButton(title: "Cancel") {
                viewModel.didTapCancel()
            }
        }
        .padding(.top, 4)
    }

    // Errors surface only once a field has been typed into, so an untouched sheet does not
    // open already showing three complaints.

    var nameError: String? {
        let value = viewModel.form.name
        guard !value.isEmpty, !CreateTrainerForm.isValidName(value) else { return nil }
        return "Enter at least \(CreateTrainerForm.nameMinimum) characters."
    }

    var emailError: String? {
        let value = viewModel.form.email
        guard !value.isEmpty, !CreateTrainerForm.isValidEmail(value) else { return nil }
        return "Enter a valid email address."
    }

    var mobileError: String? {
        let value = viewModel.form.mobile
        guard !value.isEmpty, !CreateTrainerForm.isValidMobile(value) else { return nil }
        return "Enter a \(CreateTrainerForm.mobileDigits)-digit mobile number."
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
    return CreateTrainerView(
        router: router,
        navModel: NavigationViewModel.CreateTrainerNavModel(onCreated: { _ in })
    )
}
