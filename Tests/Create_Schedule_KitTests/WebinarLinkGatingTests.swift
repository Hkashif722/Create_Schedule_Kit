//
//  WebinarLinkGatingTests.swift
//  Create_Schedule_KitTests
//
//  Which link field Step 1 shows, and when the hand-entered Teams link blocks Continue.
//  The config flag itself is never fetched here — `isTeamsStaticLinkEnabled` defaults to
//  off, which is the fail-closed state these tests rely on.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct WebinarLinkGatingTests {

    init() {
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
    }

    /// A draft complete enough that only the link can hold Continue back.
    private func completeDraft(_ type: WebinarType) -> ScheduleDraft {
        let draft = ScheduleDraft()
        draft.scheduleCode = "SC6562"
        draft.course = .init(id: 19825, title: "Test ILT006", code: "ILT006")
        draft.module = .init(id: 19785, title: "8729_Test ILT006", type: "classroom",
                             courseFee: 0, currency: "", category: nil, subCategory: nil, subSubCategory: nil)
        draft.deliveryMode = .online
        draft.webinarType = type
        draft.credential = [.init(id: 1, teamsEmail: "ENC==", username: nil, password: nil, isDefault: 1)]
        draft.timezone = .init(value: "India Standard Time", code: "IST", offset: 5.5, isdst: false, name: "IST")
        let day = Date()
        draft.startDate = day
        draft.endDate = day
        draft.registrationEndDate = day
        draft.startTime = "10:00"
        draft.endTime = "11:00"
        return draft
    }

    @MainActor
    private func viewModel(_ draft: ScheduleDraft, isEditMode: Bool = false) -> ScheduleBasicDetailsViewModel {
        ScheduleBasicDetailsViewModel(
            router: RouterEnvironmentKey.defaultValue,
            draft: draft,
            isEditMode: isEditMode,
            onBack: {},
            onContinue: {}
        )
    }

    @MainActor
    @Test func teamsShowsNoLinkFieldWhileTheConfigIsOff() {
        let model = viewModel(completeDraft(.teams))

        #expect(model.isTeamsStaticLinkEnabled == false)
        #expect(model.showTeamsLinkField == false)
        #expect(model.requiresTeamsLink == false)
        // Nothing new gets in the way of a Teams schedule created the way it is today.
        #expect(model.canContinue)
    }

    @MainActor
    @Test func zoomIsUntouchedByThisFeature() {
        let model = viewModel(completeDraft(.zoom))

        #expect(model.showTeamsLinkField == false)
        #expect(model.requiresTeamsLink == false)
        #expect(model.canContinue)
    }

    @MainActor
    @Test func offlineScheduleHasNoLinkFieldAtAll() {
        let draft = completeDraft(.zoom)
        draft.deliveryMode = .offline
        draft.webinarType = nil

        let model = viewModel(draft)
        #expect(model.showTeamsLinkField == false)
        #expect(model.canContinue)
    }

    @MainActor
    @Test func editModeNeverBlocksContinueOnALinkItCannotShow() {
        // Edit mode hides the row because `UpdatePayload` echoes the fetched schedule's own
        // meeting details — requiring a link there would wedge every Teams schedule edit.
        let model = viewModel(completeDraft(.teams), isEditMode: true)

        #expect(model.showTeamsLinkField == false)
        #expect(model.requiresTeamsLink == false)
        #expect(model.teamsLinkError == nil)
    }
}
