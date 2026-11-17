//
//  QuizPreviewTests.swift
//  Create_Schedule_KitTests
//
//  Read-only quiz preview: options + right answer off the admin quiz detail, sections and numbering.
//

import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct QuizPreviewTests {

    typealias DM = ScheduleQuizDataModel
    typealias PM = QuizPreviewDataModel

    private func detail(_ json: String) throws -> DM.QuizDetail {
        try JSONDecoder().decode(DM.QuizDetail.self, from: Data(json.utf8))
    }

    @Test func uatDetailCarriesOptions() throws {
        let d = try detail(ScheduleQuizContractTests.uatQuizDetail)
        let first = try #require(d.packages.first?.questions.first)
        #expect(first.options?.count == 1)
        #expect(first.options?.first?.optionText == "Attention-seeking")
        #expect(first.options?.first?.isCorrectAnswer == false)
    }

    @Test func correctFlagReadsEitherKey() throws {
        let options = try JSONDecoder().decode([DM.QuizOption].self, from: Data("""
        [{"optionText":"Cat","isCorrect":true},{"optionText":"Dog","isCorrectAnswer":true},{"optionText":"Fish"}]
        """.utf8))
        #expect(options.map(\.isCorrectAnswer) == [true, true, false])
    }

    @Test func sectionsRunPackagesThenDirectWithContinuousNumbers() throws {
        let d = try detail("""
        {"id":5,"title":"T","packages":[{"packageId":1,"packageName":"Pkg","questions":[
           {"assessmentQuestionId":10,"questionText":"A","optionType":"SingleSelection","difficultyLevel":"Simple","marks":1,
            "options":[{"optionText":"x","isCorrect":true},{"optionText":"y","isCorrect":false}]}]},
          {"packageId":2,"packageName":"Empty","questions":[]}],
         "questions":[{"assessmentQuestionId":11,"questionText":"B","optionType":"MultipleSelection","marks":2}]}
        """)
        let sections = PM.sections(from: d)
        #expect(sections.map(\.title) == ["Pkg", "Added Directly"])
        #expect(sections.flatMap(\.questions).map(\.number) == [1, 2])
        #expect(sections[0].questions[0].tags == ["Simple", "Single"])
        #expect(sections[0].questions[0].options.map(\.isCorrect) == [true, false])
        #expect(sections[1].questions[0].tags == ["Multiple"])
        #expect(sections[1].questions[0].options.isEmpty)
    }

    @Test func statsMatchTheSummary() throws {
        let d = try detail(ScheduleQuizContractTests.uatQuizDetail)
        let stats = PM.stats(from: d.summary)
        #expect(stats.map(\.title) == ["Pass %", "Duration", "Result shown", "Questions", "Total marks", "Attempts"])
        #expect(stats.map(\.value) == ["—", "Untimed", "Yes", "2", "2", "1"])
    }
}
