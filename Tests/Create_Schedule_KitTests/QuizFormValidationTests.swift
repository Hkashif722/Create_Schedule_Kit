//
//  QuizFormValidationTests.swift
//  Create_Schedule_KitTests
//
//  Client-side mirror of the server's rules for the quiz settings sheet and the
//  "Write a new question" form.
//

import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct QuizSettingsFormTests {

    typealias Form = QuizSettingsDataModel.Form

    private func form(title: String = "Fire — pre check", pass: String = "", duration: String = "") -> Form {
        Form(title: title, instructions: "", passText: pass, durationText: duration, showResultToLearner: true)
    }

    @Test func defaultsSeedTitleFromTheModuleName() {
        let pre = Form.defaults(kind: .pre, displayName: "Test ILT006")
        #expect(pre.title == "Test ILT006 — pre check")
        #expect(pre.instructions == "Answer every question before the session starts.")
        #expect(pre.showResultToLearner)
        #expect(Form.defaults(kind: .post, displayName: "  ").title == "Post-Schedule Quiz")
    }

    @Test func blankScoringMeansNoPassMarkAndUntimed() throws {
        let settings = try #require(form().settings)
        #expect(settings.passPercentage == nil)
        #expect(settings.durationMinutes == nil)
    }

    @Test(arguments: ["0", "60", "60.5", "60,5", "100"])
    func acceptsPassPercentages(_ value: String) {
        #expect(form(pass: value).validationMessage == nil)
    }

    @Test(arguments: ["-1", "100.5", "abc"])
    func rejectsPassPercentages(_ value: String) {
        #expect(form(pass: value).validationMessage != nil)
    }

    @Test(arguments: ["1", "30", "1440"])
    func acceptsDurations(_ value: String) {
        #expect(form(duration: value).validationMessage == nil)
    }

    @Test(arguments: ["0", "1441", "10.5", "ten"])
    func rejectsDurations(_ value: String) {
        #expect(form(duration: value).validationMessage != nil)
    }

    @Test func titleIsRequiredAndCapped() {
        #expect(form(title: "   ").validationMessage == "Enter a quiz title.")
        #expect(form(title: String(repeating: "a", count: 251)).validationMessage != nil)
        #expect(form(title: String(repeating: "a", count: 250)).validationMessage == nil)
    }

    /// The server counts .NET string length (UTF-16 units), so an emoji counts as two.
    @Test func titleLimitCountsUTF16LikeTheServer() {
        #expect(form(title: String(repeating: "😀", count: 125)).validationMessage == nil)
        #expect(form(title: String(repeating: "😀", count: 126)).validationMessage != nil)
    }

    @Test func settingsRoundTripThroughTheForm() throws {
        let original = QuizDraft.Settings(title: "T", instructions: "I", passPercentage: 70,
                                          durationMinutes: 20, showResultToLearner: false)
        let back = try #require(Form(settings: original).settings)
        #expect(back == original)
    }
}

@Suite struct QuizInlineQuestionFormTests {

    typealias Form = QuizInlineQuestionDataModel.Form
    typealias Row = QuizInlineQuestionDataModel.OptionRow

    private func valid() -> Form {
        var form = Form()
        form.questionText = "Which extinguisher is used on electrical fires?"
        form.marksText = "2"
        form.options = [Row(text: "CO2", isCorrect: true), Row(text: "Water"), Row(text: "Foam")]
        return form
    }

    @Test func aCompleteFormIsValid() {
        #expect(valid().validationMessage == nil)
        #expect(valid().payload != nil)
    }

    @Test func startsWithFourBlankOptions() {
        #expect(Form().options.count == 4)
        #expect(Form().validationMessage == "Enter the question.")
    }

    @Test(arguments: ["0", "26", "1.5", ""])
    func marksMustBeWholeOneToTwentyFive(_ marks: String) {
        var form = valid()
        form.marksText = marks
        #expect(form.validationMessage == "Marks must be a whole number from 1 to 25.")
    }

    @Test func emptyOptionsAreRejectedNotDropped() {
        var form = valid()
        form.options.append(Row(text: "  "))
        #expect(form.validationMessage == "Fill in or remove the empty option.")
    }

    @Test func duplicateOptionTextIsCaseInsensitive() {
        var form = valid()
        form.options[2].text = " co2 "
        #expect(form.validationMessage == "Two options have the same text.")
    }

    @Test func needsACorrectAnswer() {
        var form = valid()
        form.options[0].isCorrect = false
        #expect(form.validationMessage == "Mark the correct answer.")
    }

    @Test func singleSelectionIsARadioGroup() {
        var form = valid()
        form.toggleCorrect(id: form.options[1].id)
        #expect(form.options.map(\.isCorrect) == [false, true, false])
    }

    @Test func multipleSelectionTogglesIndependently() {
        var form = valid()
        form.setOptionType(.multiple)
        form.toggleCorrect(id: form.options[2].id)
        #expect(form.options.map(\.isCorrect) == [true, false, true])
        #expect(form.validationMessage == nil)
        #expect(form.payload?.optionType == "MultipleSelection")
    }

    @Test func backToSingleKeepsTheFirstCorrectAnswer() {
        var form = valid()
        form.setOptionType(.multiple)
        form.toggleCorrect(id: form.options[2].id)
        form.setOptionType(.single)
        #expect(form.options.map(\.isCorrect) == [true, false, false])
    }

    @Test func optionCountStaysWithinTwoToFive() {
        var form = valid()
        form.addOption()
        form.addOption()
        #expect(form.options.count == 5)
        #expect(form.canAddOption == false)
        form.addOption()
        #expect(form.options.count == 5)

        var small = valid()
        small.removeOption(id: small.options[2].id)
        #expect(small.options.count == 2)
        #expect(small.canRemoveOption == false)
        small.removeOption(id: small.options[0].id)
        #expect(small.options.count == 2)
    }

    @Test func textAndInstructionLimits() {
        var form = valid()
        form.questionText = String(repeating: "q", count: 1501)
        #expect(form.validationMessage != nil)
        form = valid()
        form.learnerInstruction = String(repeating: "i", count: 201)
        #expect(form.validationMessage != nil)
        form = valid()
        form.learnerInstruction = String(repeating: "😀", count: 101)
        #expect(form.validationMessage != nil)
    }

    @Test func savedQuestionIsListedAsCreatedHere() {
        let q = valid().question(id: 640)
        #expect(q.assessmentQuestionId == 640)
        #expect(q.source == .createdInline)
        #expect(q.marks == 2)
        #expect(q.source.chipTitle == "Created here")
    }

    @Test func optionLetters() {
        #expect((0..<5).map(Form.optionLetter(at:)) == ["A", "B", "C", "D", "E"])
    }
}

@Suite struct ScheduleQuizPermissionTests {

    @Test func externalTrainersCannotManageQuizzes() {
        #expect(SchedulePermissions(userRole: "ET").canManageQuiz == false)
        #expect(SchedulePermissions(userRole: "et ").canManageQuiz == false)
        #expect(SchedulePermissions(userRole: "LA").canManageQuiz)
        #expect(SchedulePermissions(userRole: "").canManageQuiz)
    }
}
