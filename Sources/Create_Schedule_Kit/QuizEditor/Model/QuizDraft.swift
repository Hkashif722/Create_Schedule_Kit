//
//  QuizDraft.swift
//  Create_Schedule_Kit
//
//  The quiz editor's working copy: settings, attached packages and directly added questions.
//  Nothing here touches the network — the editor's Save sends `savePayload` and the server
//  rebuilds the quiz from it (packages first in attach order, then direct questions).
//
//  Totals are an estimate until Save: the server drops duplicates (a bank question inside two
//  packages, or in a package and picked directly) and anything deleted from the bank since.
//

import Foundation

struct QuizDraft: Equatable {

    typealias DM = ScheduleQuizDataModel

    struct Settings: Equatable {
        var title: String
        var instructions: String
        var passPercentage: Double?
        var durationMinutes: Int?
        var showResultToLearner: Bool
    }

    struct Question: Equatable, Identifiable {
        let assessmentQuestionId: Int
        let text: String
        let optionType: DM.OptionType
        let difficulty: String?
        let marks: Double
        let source: DM.QuestionSource

        var id: Int { assessmentQuestionId }

        /// "Single · Simple"
        var metaText: String {
            [optionType.shortTitle, difficulty].compactMap { $0 }.filter { !$0.isEmpty }
                .joined(separator: " · ")
        }

        var marksText: String {
            marks.marksLabel
        }
    }

    struct Package: Equatable, Identifiable {
        let id: Int
        let name: String
        /// False once the package was deleted after being attached. Its questions stay.
        let exists: Bool
        var questionCount: Int
        var totalMarks: Double
        var questions: [Question]
        /// False for a package picked in this session until its detail has been fetched.
        var isPreviewLoaded: Bool
        /// The detail fetch failed. The package still goes out on Save; only the preview is missing.
        var isPreviewFailed: Bool = false
    }

    var settings: Settings
    var packages: [Package]
    var directQuestions: [Question]
}

// MARK: - Building

extension QuizDraft {

    init(detail: DM.QuizDetail) {
        let summary = detail.summary
        settings = Settings(
            title: summary.title,
            instructions: detail.instructions ?? "",
            passPercentage: summary.passPercentage,
            durationMinutes: summary.durationMinutes,
            showResultToLearner: summary.showResultToLearner
        )
        packages = detail.packages.map { card in
            Package(
                id: card.packageId,
                name: card.packageName ?? "Package \(card.packageId)",
                exists: card.packageExists,
                questionCount: card.questionCount,
                totalMarks: card.totalMarks,
                questions: card.questions.map { Question(quizQuestion: $0, fallbackSource: .fromPackage) },
                isPreviewLoaded: true
            )
        }
        directQuestions = detail.questions.map { Question(quizQuestion: $0, fallbackSource: .pickedFromBank) }
    }
}

extension QuizDraft.Question {

    init(quizQuestion q: ScheduleQuizDataModel.QuizQuestion, fallbackSource: ScheduleQuizDataModel.QuestionSource) {
        self.init(
            assessmentQuestionId: q.assessmentQuestionId,
            text: q.questionText ?? "",
            optionType: .init(apiValue: q.optionType),
            difficulty: q.difficultyLevel,
            marks: q.marks,
            source: q.sourceTypeId.flatMap(ScheduleQuizDataModel.QuestionSource.init(rawValue:)) ?? fallbackSource
        )
    }

    init(bankQuestion b: ScheduleQuizDataModel.BankQuestion) {
        self.init(
            assessmentQuestionId: b.id,
            text: b.questionText ?? "",
            optionType: .init(apiValue: b.optionType),
            difficulty: b.difficultyLevel,
            marks: b.marks,
            source: .pickedFromBank
        )
    }

    init(packageQuestion p: ScheduleQuizDataModel.PackageDetail.Question) {
        self.init(
            assessmentQuestionId: p.assessmentQuestionId,
            text: p.questionText ?? "",
            optionType: .init(apiValue: p.optionType),
            difficulty: p.difficultyLevel,
            marks: p.marks,
            source: .fromPackage
        )
    }
}

// MARK: - Editing

extension QuizDraft {

    var attachedPackageIDs: Set<Int> { Set(packages.map(\.id)) }

    /// Rows the bank picker must not offer again: everything already listed, packaged or direct.
    var blockedBankQuestionIDs: Set<Int> {
        Set(directQuestions.map(\.id) + packages.flatMap { $0.questions.map(\.id) })
    }

    /// Appends in pick order, skipping packages already attached.
    mutating func attach(_ items: [DM.PackageListItem]) {
        for item in items where !attachedPackageIDs.contains(item.id) {
            packages.append(Package(
                id: item.id,
                name: item.packageName,
                exists: true,
                questionCount: item.questionCount - item.unavailableQuestionCount,
                totalMarks: item.totalMarks,
                questions: [],
                isPreviewLoaded: false
            ))
        }
    }

    /// Fills a freshly attached package's question list. Questions gone from the bank are left
    /// out — the server drops them on Save anyway.
    mutating func applyPreview(_ detail: DM.PackageDetail) {
        guard let index = packages.firstIndex(where: { $0.id == detail.id }) else { return }
        let available = detail.questions.filter { $0.isAvailable ?? true }
        packages[index].questions = available.map(Question.init(packageQuestion:))
        packages[index].questionCount = available.count
        packages[index].totalMarks = available.reduce(0) { $0 + $1.marks }
        packages[index].isPreviewLoaded = true
    }

    mutating func markPreviewFailed(packageID: Int) {
        guard let index = packages.firstIndex(where: { $0.id == packageID }),
              !packages[index].isPreviewLoaded else { return }
        packages[index].isPreviewFailed = true
    }

    mutating func removePackage(id: Int) {
        packages.removeAll { $0.id == id }
    }

    /// Appends picks, skipping anything already in the quiz.
    mutating func add(_ questions: [Question]) {
        var blocked = blockedBankQuestionIDs
        for question in questions where !blocked.contains(question.id) {
            directQuestions.append(question)
            blocked.insert(question.id)
        }
    }

    mutating func removeQuestion(id: Int) {
        directQuestions.removeAll { $0.id == id }
    }
}

// MARK: - Totals & payload

extension QuizDraft {

    struct Totals: Equatable {
        let questions: Int
        let marks: Double
    }

    /// Server order (packages, then direct), each bank question counted once. A package whose
    /// preview hasn't loaded yet contributes its list-row counts as-is.
    var estimatedTotals: Totals {
        var seen = Set<Int>()
        var count = 0
        var marks = 0.0
        for package in packages {
            guard package.isPreviewLoaded else {
                count += package.questionCount
                marks += package.totalMarks
                continue
            }
            for question in package.questions where seen.insert(question.id).inserted {
                count += 1
                marks += question.marks
            }
        }
        for question in directQuestions where seen.insert(question.id).inserted {
            count += 1
            marks += question.marks
        }
        return Totals(questions: count, marks: marks)
    }

    var isEmpty: Bool { packages.isEmpty && directQuestions.isEmpty }

    var savePayload: DM.SaveQuizPayload {
        let instructions = settings.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return DM.SaveQuizPayload(
            title: settings.title.trimmingCharacters(in: .whitespacesAndNewlines),
            instructions: instructions.isEmpty ? nil : instructions,
            passPercentage: settings.passPercentage,
            durationMinutes: settings.durationMinutes,
            showResultToLearner: settings.showResultToLearner,
            packageIds: packages.map(\.id),
            questions: directQuestions.map {
                .init(assessmentQuestionId: $0.assessmentQuestionId, isCreatedInline: $0.source == .createdInline)
            }
        )
    }
}
