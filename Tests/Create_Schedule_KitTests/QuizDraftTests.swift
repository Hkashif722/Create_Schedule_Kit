//
//  QuizDraftTests.swift
//  Create_Schedule_KitTests
//
//  The editor's working copy: building from the server, attaching packages, picking from the
//  bank, estimated totals (server de-duplicates) and the Save body.
//

import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct QuizDraftTests {

    typealias DM = ScheduleQuizDataModel

    private func question(_ id: Int, marks: Double = 1, source: DM.QuestionSource = .pickedFromBank) -> QuizDraft.Question {
        .init(assessmentQuestionId: id, text: "Q\(id)", optionType: .single, difficulty: "Simple",
              marks: marks, source: source)
    }

    private func package(_ id: Int, questions: [QuizDraft.Question], loaded: Bool = true) -> QuizDraft.Package {
        .init(id: id, name: "P\(id)", exists: true, questionCount: questions.count,
              totalMarks: questions.reduce(0) { $0 + $1.marks }, questions: questions, isPreviewLoaded: loaded)
    }

    private func draft(packages: [QuizDraft.Package] = [], direct: [QuizDraft.Question] = []) -> QuizDraft {
        QuizDraft(
            settings: .init(title: "T", instructions: "", passPercentage: 60, durationMinutes: nil, showResultToLearner: true),
            packages: packages,
            directQuestions: direct
        )
    }

    // MARK: - Building

    @Test func buildsFromTheServerCopy() throws {
        let detail = try JSONDecoder().decode(DM.QuizDetail.self, from: Data(ScheduleQuizContractTests.uatQuizDetail.utf8))
        let draft = QuizDraft(detail: detail)
        #expect(draft.settings.title == "class56 — pre check")
        #expect(draft.settings.instructions == "Answer every question before the session starts.")
        #expect(draft.packages.map(\.id) == [1])
        #expect(draft.packages[0].isPreviewLoaded)
        #expect(draft.packages[0].questions.map(\.id) == [1, 2])
        #expect(draft.packages[0].questions[1].optionType == .multiple)
        #expect(draft.estimatedTotals == .init(questions: 2, marks: 2))
        #expect(draft.savePayload.packageIds == [1])
        #expect(draft.savePayload.questions.isEmpty)
    }

    // MARK: - Totals

    @Test func totalsCountEachBankQuestionOnce() {
        let shared = question(5, marks: 2)
        let d = draft(
            packages: [package(1, questions: [question(1), shared]), package(2, questions: [shared, question(7, marks: 3)])],
            direct: [question(5, marks: 2), question(9)]
        )
        // 1, 5, 7, 9 — 5 appears three times.
        #expect(d.estimatedTotals == .init(questions: 4, marks: 7))
    }

    @Test func anUnloadedPackageContributesItsListCounts() {
        var unloaded = package(3, questions: [], loaded: false)
        unloaded.questionCount = 4
        unloaded.totalMarks = 8
        let d = draft(packages: [unloaded], direct: [question(1)])
        #expect(d.estimatedTotals == .init(questions: 5, marks: 9))
    }

    // MARK: - Packages

    @Test func attachSkipsPackagesAlreadyOnTheQuizAndDiscountsUnavailableQuestions() {
        var d = draft(packages: [package(1, questions: [question(1)])])
        d.attach([
            .init(id: 1, packageName: "dup", description: nil, questionCount: 9, unavailableQuestionCount: 0, totalMarks: 9),
            .init(id: 2, packageName: "Fire", description: nil, questionCount: 6, unavailableQuestionCount: 1, totalMarks: 11)
        ])
        #expect(d.packages.map(\.id) == [1, 2])
        #expect(d.packages[1].questionCount == 5)
        #expect(d.packages[1].isPreviewLoaded == false)
    }

    @Test func previewDropsQuestionsGoneFromTheBank() throws {
        var d = draft()
        d.attach([.init(id: 12, packageName: "Fire", description: nil, questionCount: 2, unavailableQuestionCount: 1, totalMarks: 3)])
        let detail = try JSONDecoder().decode(DM.PackageDetail.self, from: Data("""
        {"id":12,"packageName":"Fire","questions":[
          {"assessmentQuestionId":1,"questionText":"a","optionType":"SingleSelection","difficultyLevel":"Simple","marks":1,"isAvailable":true},
          {"assessmentQuestionId":2,"questionText":"b","optionType":"SingleSelection","difficultyLevel":"Simple","marks":2,"isAvailable":false}]}
        """.utf8))
        d.applyPreview(detail)
        #expect(d.packages[0].isPreviewLoaded)
        #expect(d.packages[0].questions.map(\.id) == [1])
        #expect(d.packages[0].questionCount == 1)
        #expect(d.packages[0].totalMarks == 1)
    }

    @Test func aFailedPreviewIsFlaggedButKeepsTheListCounts() {
        var d = draft(packages: [package(1, questions: [question(1)])])
        d.attach([.init(id: 2, packageName: "Fire", description: nil, questionCount: 3, unavailableQuestionCount: 0, totalMarks: 6)])
        d.markPreviewFailed(packageID: 2)
        d.markPreviewFailed(packageID: 1)
        #expect(d.packages[1].isPreviewFailed)
        #expect(d.packages[0].isPreviewFailed == false)
        #expect(d.estimatedTotals == .init(questions: 4, marks: 7))
        #expect(d.savePayload.packageIds == [1, 2])
    }

    @Test func previewForAPackageNoLongerAttachedIsIgnored() throws {
        var d = draft()
        let detail = try JSONDecoder().decode(DM.PackageDetail.self, from: Data(#"{"id":99,"questions":[]}"#.utf8))
        d.applyPreview(detail)
        #expect(d.packages.isEmpty)
    }

    // MARK: - Direct questions

    @Test func picksAlreadyInTheQuizAreSkipped() {
        var d = draft(packages: [package(1, questions: [question(10)])], direct: [question(20)])
        d.add([question(10), question(20), question(30), question(30)])
        #expect(d.directQuestions.map(\.id) == [20, 30])
        #expect(d.blockedBankQuestionIDs == [10, 20, 30])
    }

    @Test func removeTakesOutOnlyThatRow() {
        var d = draft(packages: [package(1, questions: [question(1)]), package(2, questions: [])],
                      direct: [question(3), question(4)])
        d.removeQuestion(id: 3)
        d.removePackage(id: 1)
        #expect(d.directQuestions.map(\.id) == [4])
        #expect(d.packages.map(\.id) == [2])
    }

    // MARK: - Save body

    @Test func savePayloadMarksInlineQuestionsAndTrimsSettings() {
        var d = draft(packages: [package(12, questions: [question(1)])],
                      direct: [question(640, source: .createdInline), question(517)])
        d.settings.title = "  Fire  "
        d.settings.instructions = "   "
        let payload = d.savePayload
        #expect(payload.title == "Fire")
        #expect(payload.instructions == nil)
        #expect(payload.packageIds == [12])
        #expect(payload.questions == [.init(assessmentQuestionId: 640, isCreatedInline: true),
                                      .init(assessmentQuestionId: 517, isCreatedInline: false)])
    }

    @Test func aPackagePreviewDoesNotCountAsAnUnsavedChange() throws {
        var d = draft()
        d.attach([.init(id: 12, packageName: "Fire", description: nil, questionCount: 1, unavailableQuestionCount: 0, totalMarks: 1)])
        let before = d.savePayload
        let detail = try JSONDecoder().decode(DM.PackageDetail.self, from: Data(#"{"id":12,"questions":[]}"#.utf8))
        d.applyPreview(detail)
        #expect(d.savePayload == before)
    }

    @Test func questionMetaAndMarksText() {
        let q = QuizDraft.Question(assessmentQuestionId: 1, text: "x", optionType: .multiple, difficulty: nil,
                                   marks: 1, source: .createdInline)
        #expect(q.metaText == "Multiple")
        #expect(q.marksText == "1 mark")
        #expect(question(2, marks: 2.5).marksText == "2.5 marks")
    }
}
