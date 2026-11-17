//
//  QuizPreviewDataModel.swift
//  Create_Schedule_Kit
//
//  Display shapes for the read-only quiz preview. Built from `ScheduleQuizDataModel.QuizDetail`,
//  no endpoint of its own.
//

import Foundation

struct QuizPreviewDataModel {

    typealias DM = ScheduleQuizDataModel

    struct Stat: Identifiable, Equatable {
        let title: String
        let value: String

        var id: String { title }
    }

    struct Option: Identifiable, Equatable {
        let id: Int
        let text: String
        let isCorrect: Bool
    }

    struct Question: Identifiable, Equatable {
        let id: Int
        let number: Int
        let text: String
        let marks: Double
        let tags: [String]
        let options: [Option]
    }

    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let questions: [Question]
    }
}

// MARK: - Building

extension QuizPreviewDataModel {

    /// Server order: packages first, then direct picks. Numbering runs across all of them.
    static func sections(from detail: DM.QuizDetail) -> [Section] {
        var number = 0
        func questions(_ list: [DM.QuizQuestion]) -> [Question] {
            list.map { q in
                number += 1
                return Question(quizQuestion: q, number: number)
            }
        }

        var result = detail.packages.map { card in
            Section(
                id: "package-\(card.packageId)",
                title: card.packageName ?? "Package \(card.packageId)",
                questions: questions(card.questions)
            )
        }
        if !detail.questions.isEmpty {
            result.append(Section(id: "direct", title: "Added Directly", questions: questions(detail.questions)))
        }
        return result.filter { !$0.questions.isEmpty }
    }

    static func stats(from summary: DM.QuizSummary) -> [Stat] {
        [
            Stat(title: "Pass %", value: summary.passText),
            Stat(title: "Duration", value: summary.durationText),
            Stat(title: "Result shown", value: summary.showResultToLearner ? "Yes" : "No"),
            Stat(title: "Questions", value: "\(summary.totalQuestions)"),
            Stat(title: "Total marks", value: summary.totalMarks.marksText),
            Stat(title: "Attempts", value: "\(summary.attemptCount)")
        ]
    }
}

extension QuizPreviewDataModel.Question {

    init(quizQuestion q: ScheduleQuizDataModel.QuizQuestion, number: Int) {
        let difficulty = q.difficultyLevel?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            id: q.assessmentQuestionId,
            number: number,
            text: q.questionText ?? "",
            marks: q.marks,
            tags: [difficulty, ScheduleQuizDataModel.OptionType(apiValue: q.optionType).shortTitle]
                .compactMap { $0 }
                .filter { !$0.isEmpty },
            options: (q.options ?? []).enumerated().map { offset, option in
                .init(id: offset, text: option.optionText, isCorrect: option.isCorrectAnswer)
            }
        )
    }
}
