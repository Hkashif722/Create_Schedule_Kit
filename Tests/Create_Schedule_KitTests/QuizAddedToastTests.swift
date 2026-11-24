//
//  QuizAddedToastTests.swift
//  Create_Schedule_KitTests
//
//  Editor opened right after a create says "Quiz added to schedule successfully." once.
//  Opening an existing quiz says nothing. Checks run before any await, so the load
//  kicked off by onAppear (no server here) can't land in between.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import Testing
@testable import Create_Schedule_Kit

@Suite struct QuizAddedToastTests {

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
    private func editor(isJustAdded: Bool) -> QuizEditorViewModel {
        QuizEditorViewModel(
            router: RouterEnvironmentKey.defaultValue,
            navModel: .init(
                quizID: 101,
                kind: .pre,
                onChanged: {},
                isOtherSlotEmpty: { true },
                onAddOtherQuiz: {},
                isJustAdded: isJustAdded
            )
        )
    }

    @MainActor
    @Test func justAddedQuizToastsOnOpen() {
        let model = editor(isJustAdded: true)
        model.onAppear()

        #expect(model.toast?.message == "Quiz added to schedule successfully.")
        #expect(model.toast?.style == .success)
    }

    // coming back from a picker/sheet re-fires onAppear. must not toast again
    @MainActor
    @Test func justAddedToastShowsOnlyOnce() {
        let model = editor(isJustAdded: true)
        model.onAppear()
        model.toast = nil
        model.onAppear()

        #expect(model.toast == nil)
    }

    @MainActor
    @Test func existingQuizOpensQuietly() {
        let model = editor(isJustAdded: false)
        model.onAppear()

        #expect(model.toast == nil)
    }
}
