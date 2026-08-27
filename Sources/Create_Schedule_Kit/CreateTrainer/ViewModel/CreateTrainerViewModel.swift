//
//  CreateTrainerViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the Create New Trainer bottom sheet. "Add Trainer" runs two calls in sequence:
//  a mobile-number existence check, then the account create. The created trainer is handed
//  back to Step 2 through `navModel.onCreated` and the sheet dismisses itself.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class CreateTrainerViewModel: BaseViewModel {

    // MARK: - Navigation Model
    let navModel: NavigationViewModel.CreateTrainerNavModel

    // MARK: - Published State
    @Published var form = CreateTrainerForm()

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.CreateTrainerNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived UI state
extension CreateTrainerViewModel {

    var isAddEnabled: Bool { form.isValid }
}

// MARK: - Actions
extension CreateTrainerViewModel {

    /// Digits-only, capped at the expected length — the value is both the login id and the
    /// existence-check search text, so it must not carry formatting.
    func onMobileChanged(_ newValue: String) {
        let sanitized = CreateTrainerForm.sanitizedMobile(newValue)
        guard sanitized != form.mobile else { return }
        form.mobile = sanitized
    }

    func didTapAddTrainer() {
        guard isAddEnabled else {
            if let message = form.validationMessage {
                toast = Toast(style: .warning, message: message)
            }
            return
        }
        Task { [weak self] in await self?.createTrainer() }
    }

    func didTapCancel() {
        goBack()
    }
}

// MARK: - API
extension CreateTrainerViewModel {

    /// Existence check first, create second. A failure in either step leaves the sheet open
    /// with the typed values intact so the user can correct and retry.
    @MainActor
    private func createTrainer() async {
        loadingState = .loading(message: "Please wait...")

        let exists: Bool
        do {
            exists = try await checkUserExists()
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
            return
        }

        guard !exists else {
            loadingState = .none
            toast = Toast(
                style: .warning,
                message: "A user with this mobile number already exists. Use \"Select User from System\" instead."
            )
            return
        }

        do {
            let created = try await postCreateUser()
            guard let id = created.id, id > 0 else {
                loadingState = .none
                toast = Toast(style: .error, message: "Could not create the trainer. Please try again.")
                return
            }
            loadingState = .none
            let trainer = ScheduleLogisticsDataModel.Trainer(created: created, form: form)
            // Step 2 owns the success toast — this sheet is torn down at dismissal and its
            // toast overlay with it.
            navModel.onCreated(trainer)
            goBack()
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }

    /// `User/Exist` keyed on the mobile column. Both the column name and the number are
    /// encrypted in-package before sending.
    private func checkUserExists() async throws -> Bool {
        typealias Request = CreateTrainerDataModel.UserExistRequest
        let payload = Request.Payload(
            searchByColumn: EncryptDecryptUtility.shared.newEncryptValueString(
                valueStr: Request.mobileColumn
            ),
            searchText: EncryptDecryptUtility.shared.newEncryptValueString(
                valueStr: form.trimmedMobile
            )
        )
        let response = try await ApiService.shared.requestPostHeader(
            type: CreateTrainerDataModel.UserExistResponse.self,
            model: Request(),
            payload: payload
        )
        return response.userExists
    }

    private func postCreateUser() async throws -> CreateTrainerDataModel.CreateUserResponse {
        let payload = CreateTrainerDataModel.CreateUserPayload(
            form: form,
            customerCode: CreateScheduleKitAPIManager.shared.getOrgCode
        )
        return try await ApiService.shared.requestPostHeader(
            type: CreateTrainerDataModel.CreateUserResponse.self,
            model: CreateTrainerDataModel.CreateUserRequest(),
            payload: payload
        )
    }
}
