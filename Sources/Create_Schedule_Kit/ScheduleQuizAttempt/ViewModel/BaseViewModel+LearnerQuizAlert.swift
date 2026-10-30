//
//  BaseViewModel+LearnerQuizAlert.swift
//  Create_Schedule_Kit
//
//  Two-button confirm popup shared by the learner quiz screens (start, exit, submit).
//

import SwiftUI
import SwiftUIUtilities
import NetworkService

extension BaseViewModel {

    func presentLearnerQuizAlert(
        title: String,
        message: String,
        alertType: AlertType = .none,
        primaryTitle: String,
        secondaryTitle: String? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        let model = CustomAlertPopupModel(
            title: AttributedString(title),
            alertType: alertType,
            content: {
                Text(message)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
            },
            primaryButtonTitle: primaryTitle,
            primaryAction: { [weak self] in
                self?.router.dismissModal()
                onPrimary()
            },
            secondaryButtonTitle: secondaryTitle,
            secondaryAction: secondaryTitle == nil ? nil : { [weak self] in
                self?.router.dismissModal()
                onSecondary?()
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.customAlertPopupView(model))
        )
    }

    /// `handleAPIError` only reads converted errors; a raw `APIError` loses the server's text.
    /// Assessment 403/404/409s carry a machine code ("DependancyExist") where copy should be,
    /// so those get the description or the generic line instead.
    func reportLearnerQuizError(_ error: Error, resetLoadingState: Bool = true) {
        if let assessmentError = AssessmentAPIError(error) {
            if resetLoadingState { loadingState = .none }
            toast = Toast(style: .error, message: assessmentError.message(fallback: AssessmentAPIError.genericMessage))
        } else if let apiError = error as? APIError {
            handleAPIError(apiError.toUIError(), resetLoadingState: resetLoadingState, showToast: true)
        } else {
            handleAPIError(error, resetLoadingState: resetLoadingState, showToast: true)
        }
    }
}
