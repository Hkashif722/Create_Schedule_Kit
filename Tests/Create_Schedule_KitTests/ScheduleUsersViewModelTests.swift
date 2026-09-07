//
//  ScheduleUsersViewModelTests.swift
//  Create_Schedule_KitTests
//
//  The mode-driven behaviour of the shared waiting/availability screen, exercised through
//  the view model's pure state — no networking.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleUsersViewModelTests {

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
    private func viewModel(_ mode: ScheduleUsersDataModel.Mode) -> ScheduleUsersViewModel {
        ScheduleUsersViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(mode: mode, scheduleID: 4307, courseID: 59258, moduleID: 46404)
        )
    }

    @MainActor
    @Test func theScreenTakesItsTitleFromTheMode() {
        #expect(viewModel(.waiting).title == "Waiting List")
        #expect(viewModel(.availability).title == "Users Availability")
    }

    @MainActor
    @Test func theSectionCaptionGainsACountOnlyOnceThereIsOne() {
        let model = viewModel(.availability)
        // Nothing loaded yet — no "(0)" while the total is still unknown.
        #expect(model.sectionTitle == "USERS")
    }

    @MainActor
    @Test func theBodyCarriesTheSchedulesIdentifiers() {
        let payload = viewModel(.waiting).payload(page: 2)

        #expect(payload.scheduleID == 4307)
        #expect(payload.courseId == 59258)
        // The sibling attendance bodies send 0 rather than the real module id.
        #expect(payload.moduleId == 0)
        #expect(payload.page == 2)
        #expect(payload.pageSize == 10)
        #expect(payload.type == nil)
    }

    @MainActor
    @Test func anEmptyBoxSearchesForNothing() {
        let model = viewModel(.availability)
        model.searchText = "   "

        let payload = model.payload(page: 1)
        #expect(payload.search == nil)
        #expect(payload.searchText == nil)
    }

    @MainActor
    @Test func aQueryTravelsWithTheColumnItFilters() {
        let model = viewModel(.availability)
        model.searchText = "  Sunny  "

        let payload = model.payload(page: 1)
        #expect(payload.search == "userName")
        // Trimmed — the trailing spaces would otherwise match nothing server-side.
        #expect(payload.searchText == "Sunny")
    }

    @MainActor
    @Test func paginationStartsOnPageOneWithTenPerPage() {
        let model = viewModel(.waiting)
        #expect(model.itemsPerPage == 10)
        #expect(model.items.isEmpty)
        #expect(model.payload(page: 1).page == 1)
    }
}
