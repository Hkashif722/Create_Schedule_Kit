//
//  NominateSearchResetTests.swift
//  Create_Schedule_KitTests
//
//  Bug: after changing the filter parameter, the previously selected search value stayed
//  in the search field instead of the placeholder coming back — so the next search ran a
//  value belonging to the old parameter.
//
//  The field's text lives inside `DropDownMenuListViewPkg`, which reaches it two ways:
//  `selectedOption` (a picked suggestion) and the focus/reset token (anything typed but
//  never picked). Both are asserted here.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct NominateSearchResetTests {

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

    @MainActor
    private func viewModel() -> NominateUsersViewModel {
        NominateUsersViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(scheduleCode: "SC8450", courseID: 59207, moduleID: 46289, onComplete: {})
        )
    }

    private func column(_ id: Int, _ name: String) throws -> NominateUsersDataModel.AccessibilityColumn {
        let json = #"{"id": \#(id), "configuredColumnName": "\#(name)", "changedColumnName": "\#(name)"}"#
        return try JSONDecoder().decode(
            NominateUsersDataModel.AccessibilityColumn.self,
            from: Data(json.utf8)
        )
    }

    private func suggestion(_ id: Int, _ name: String) throws -> NominateUsersDataModel.TypeAheadResult {
        try JSONDecoder().decode(
            NominateUsersDataModel.TypeAheadResult.self,
            from: Data(#"{"id": \#(id), "name": "\#(name)"}"#.utf8)
        )
    }

    @MainActor
    @Test func changingTheParameterClearsAPickedValue() throws {
        let model = viewModel()
        model.selectColumn(try column(1, "UserName"))
        model.selectSuggestion(try suggestion(11998, "Anand"))

        #expect(model.selectedSuggestion != nil)
        #expect(model.searchText == "Anand")

        model.selectColumn(try column(2, "EmailId"))

        // nil selection is what sends the control back to its placeholder.
        #expect(model.selectedSuggestion == nil)
        #expect(model.searchText.isEmpty)
        #expect(model.typeaheadResults.isEmpty)
    }

    @MainActor
    @Test func changingTheParameterAlsoClearsAValueTypedButNeverPicked() throws {
        let model = viewModel()
        model.selectColumn(try column(1, "UserName"))
        model.searchText = "anand1@gmail.com"
        let tokenBefore = model.searchResetToken

        model.selectColumn(try column(2, "EmailId"))

        // Text typed into the control never reached the model, so only the reset token
        // can clear it.
        #expect(model.searchResetToken == tokenBefore + 1)
        #expect(model.searchText.isEmpty)
    }

    @MainActor
    @Test func rePickingTheSameParameterChangesNothing() throws {
        let model = viewModel()
        let userName = try column(1, "UserName")
        model.selectColumn(userName)
        model.selectSuggestion(try suggestion(11998, "Anand"))
        let tokenBefore = model.searchResetToken

        model.selectColumn(userName)

        #expect(model.searchText == "Anand")
        #expect(model.selectedSuggestion != nil)
        #expect(model.searchResetToken == tokenBefore)
    }

    @MainActor
    @Test func switchingParameterWithAnEmptyBoxDoesNotPullFocus() throws {
        let model = viewModel()
        model.selectColumn(try column(1, "UserName"))
        let tokenBefore = model.searchResetToken

        model.selectColumn(try column(2, "EmailId"))

        // Nothing to clear, so no reset request — the token drives keyboard focus too.
        #expect(model.searchResetToken == tokenBefore)
    }
}
