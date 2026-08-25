//
//  CancelScheduleViewModel.swift
//  Create_Schedule_Kit
//
//  Drives the Cancel Schedule bottom sheet: fetches whether the schedule already has nominated
//  users (which decides the warning banner), validates the mandatory reason, and posts the
//  cancellation. Whether the sheet may open at all is decided upstream by
//  `ScheduleListViewModel.didTapCancel` — the registration-window gate lives there.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class CancelScheduleViewModel: BaseViewModel {

    /// Mirrors the web client's reason field: mandatory, with a floor and a hard cap.
    static let reasonMinimum = 10
    static let reasonLimit = 300

    // MARK: - Dependencies
    let navModel: NavigationViewModel.CancelScheduleNavModel

    // MARK: - Screen state
    @Published var reason: String = ""
    @Published private(set) var hasNominations: Bool = false

    private var hasLoaded = false

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.CancelScheduleNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived UI state
extension CancelScheduleViewModel {

    var scheduleCode: String { navModel.scheduleCode.isEmpty ? "-" : navModel.scheduleCode }
    var moduleName: String { navModel.moduleName.isEmpty ? "-" : navModel.moduleName }

    var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSubmitEnabled: Bool {
        trimmedReason.count >= Self.reasonMinimum
    }

    /// The field is mandatory, but an untouched sheet should not open already showing an error —
    /// the warning border appears only once the user has typed something that is still too short.
    var showsReasonWarningBorder: Bool {
        !reason.isEmpty && !isSubmitEnabled
    }

    /// "0/300" — counts the raw text, matching what the editor's own cap truncates.
    var characterCountText: String {
        "\(reason.count)/\(Self.reasonLimit)"
    }

    var helperText: String {
        "Min. \(Self.reasonMinimum) characters. Shared with nominated users."
    }
}

// MARK: - Lifecycle
extension CancelScheduleViewModel {

    func onAppear() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { [weak self] in await self?.fetchNominationDetails() }
    }
}

// MARK: - Actions
extension CancelScheduleViewModel {

    func didTapCancelSchedule() {
        // The loading overlay only appears on the next runloop pass, so a fast double tap would
        // otherwise post the cancellation twice.
        guard !loadingState.isLoading else { return }
        guard isSubmitEnabled else {
            toast = Toast(
                style: .warning,
                message: "Please enter at least \(Self.reasonMinimum) characters."
            )
            return
        }
        Task { [weak self] in await self?.submit() }
    }

    func didTapKeep() {
        router.dismissScreen()
    }

    func didTapClose() {
        router.dismissScreen()
    }
}

// MARK: - API
extension CancelScheduleViewModel {

    /// Advisory only — the banner is informational, so a failure here must never block the
    /// cancellation or interrupt the user. `try?` rather than `handleAPIError`: the latter
    /// presents a modal alert when `showToast` is false, which would land on top of the sheet
    /// that just opened.
    @MainActor
    private func fetchNominationDetails() async {
        hasNominations = (try? await ApiService.shared.requestGetHeader(
            type: Bool.self,
            model: CancelScheduleDataModel.GetNominationCountDetailsRequest(
                scheduleID: navModel.scheduleID
            )
        )) ?? false
    }

    /// The API wants the AES-encrypted schedule id, but the list carries only the numeric one,
    /// so it is encrypted in-package — same contract as the nominee-delete call.
    private var encryptedScheduleID: String {
        EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "\(navModel.scheduleID)")
    }

    /// The happy path is an empty body, which `ApiService` surfaces as `APIError.noData` — the one
    /// error that means success here. When a body *is* present it is the shared status envelope,
    /// and a non-200 `statusCode` is a refusal even though the transport succeeded.
    @MainActor
    private func submit() async {
        loadingState = .loading(title: "Cancelling", message: "Please wait.")
        let payload = CancelScheduleDataModel.CancelPayload(
            scheduleID: encryptedScheduleID,
            reason: trimmedReason
        )
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: CancelScheduleDataModel.CancelResponse.self,
                model: CancelScheduleDataModel.CancellationScheduleRequest(),
                payload: payload
            )
            // A missing statusCode means the endpoint answered without the envelope, which for
            // this route is a success.
            if let statusCode = response.statusCode, statusCode != 200 {
                loadingState = .none
                toast = Toast(
                    style: .error,
                    message: response.message ?? "Could not cancel this schedule."
                )
                return
            }
        } catch let error as APIError where error == .noData {
            // Empty body — the documented success response.
        } catch let error as APIError {
            handleAPIError(error.toUIError(), resetLoadingState: true, showToast: true)
            return
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
            return
        }

        loadingState = .none
        Logger.shared.log(.info, message: "Schedule \(navModel.scheduleID) cancelled successfully")
        // Dismiss first, then hand the success feedback to the list, which is on screen again.
        router.dismissScreen()
        navModel.onCancelled()
    }
}
