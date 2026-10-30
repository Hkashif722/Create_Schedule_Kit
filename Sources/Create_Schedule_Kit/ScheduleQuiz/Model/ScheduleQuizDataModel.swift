//
//  ScheduleQuizDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs for schedule-level Pre/Post quiz authoring, plus the question-package
//  routes the editor reads. Both controllers live on the Assessment API, same host and `/api/v1`
//  prefix as everything else in the package.
//
//   • ILTScheduleQuiz/Schedule/{scheduleId}   GET  → ScheduleQuizzes     POST → IDResponse (create)
//   • ILTScheduleQuiz/{id}                    GET  → QuizDetail          POST → QuizSaveResult
//   • ILTScheduleQuiz/{id}/Publish            POST → IDResponse
//   • ILTScheduleQuiz/{id}[?confirm=true]     DELETE → APIMessage
//   • ILTScheduleQuiz/GetBankQuestions        POST → Page<BankQuestion>
//   • ILTScheduleQuiz/InlineQuestion          POST → IDResponse (new bank question id)
//   • QuestionPackage/GetPackages             POST → Page<PackageListItem>
//   • QuestionPackage/{id}                    GET  → PackageDetail
//
//  Marks and percentages come back as decimals (`2.00`), so they decode as `Double`.
//

import Foundation
import SwiftUI
import NetworkService

enum ScheduleQuizDataModel {

    // MARK: - Endpoints (quiz)

    private static func quizPath(_ segments: String...) -> String {
        ([APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltScheduleQuiz] + segments)
            .joined(separator: "/")
    }

    private static func packagePath(_ segments: String...) -> String {
        ([APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.questionPackage] + segments)
            .joined(separator: "/")
    }

    /// GET both slots for a schedule. A null slot means that quiz was never created.
    struct GetScheduleQuizzesRequest: EndpointModel {
        let scheduleID: Int
        var path: String { ScheduleQuizDataModel.quizPath(APIConst.scheduleSegment, "\(scheduleID)") }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// POST an empty quiz into a slot. Questions arrive later through Save.
    struct CreateQuizRequest: EndpointModel {
        let scheduleID: Int
        var path: String { ScheduleQuizDataModel.quizPath(APIConst.scheduleSegment, "\(scheduleID)") }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    struct GetQuizRequest: EndpointModel {
        let quizID: Int
        var path: String { ScheduleQuizDataModel.quizPath("\(quizID)") }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// POST the full editor state. Never a diff.
    struct SaveQuizRequest: EndpointModel {
        let quizID: Int
        var path: String { ScheduleQuizDataModel.quizPath("\(quizID)") }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    struct PublishQuizRequest: EndpointModel {
        let quizID: Int
        var path: String { ScheduleQuizDataModel.quizPath("\(quizID)", APIConst.publish) }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// First call goes without `confirm`. If learners attempted it the server answers
    /// 409 `DependancyExist` and wants the same call again with `?confirm=true`.
    struct DeleteQuizRequest: EndpointModel {
        let quizID: Int
        let confirm: Bool
        var path: String { ScheduleQuizDataModel.quizPath("\(quizID)") + (confirm ? "?confirm=true" : "") }
        var method: HTTPMethod { .delete }
        var headers: [String: String]? { nil }
    }

    struct GetBankQuestionsRequest: EndpointModel {
        var path: String { ScheduleQuizDataModel.quizPath(APIConst.getBankQuestions) }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    struct InlineQuestionRequest: EndpointModel {
        var path: String { ScheduleQuizDataModel.quizPath(APIConst.inlineQuestion) }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    // MARK: - Endpoints (question package)

    /// POST so filters ride in the body. Newest first. `status: true` hides inactive ones.
    struct GetPackagesRequest: EndpointModel {
        var path: String { ScheduleQuizDataModel.packagePath(APIConst.getPackages) }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    /// Admin-only shape: options carry `isCorrectAnswer`. Never reuse for learners.
    struct GetPackageRequest: EndpointModel {
        let packageID: Int
        var path: String { ScheduleQuizDataModel.packagePath("\(packageID)") }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    // MARK: - Shared shapes

    struct EmptyBody: Encodable {}

    struct IDResponse: Decodable {
        let id: Int
    }

    struct APIMessage: Decodable {
        let message: String?
        let description: String?
    }

    struct Page<Item: Decodable>: Decodable {
        let data: [Item]
        let totalCount: Int

        enum CodingKeys: String, CodingKey { case data, totalCount }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            data = try c.decodeIfPresent([Item].self, forKey: .data) ?? []
            totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        }
    }

    // MARK: - Enums

    enum QuizKind: Int, Codable, CaseIterable, Identifiable {
        case pre = 1
        case post = 2

        var id: Int { rawValue }

        /// "PRE" / "POST" pill text.
        var badge: String { self == .pre ? "PRE" : "POST" }
        /// "Pre-Schedule Quiz" — the slot name on the step.
        var slotTitle: String { self == .pre ? "Pre-Schedule Quiz" : "Post-Schedule Quiz" }
        /// "Pre quiz" — editor header and dialogs.
        var shortTitle: String { self == .pre ? "Pre quiz" : "Post quiz" }
        var lowercasedTitle: String { self == .pre ? "pre quiz" : "post quiz" }
        /// "Pre Quiz" — the learner's Live Quiz row.
        var learnerTitle: String { self == .pre ? "Pre Quiz" : "Post Quiz" }

        var badgeForeground: Color {
            self == .pre ? Color(red: 0.55, green: 0.36, blue: 0.0) : Color(red: 0.42, green: 0.22, blue: 0.75)
        }

        var badgeBackground: Color {
            self == .pre ? Color(red: 1.0, green: 0.85, blue: 0.40) : Color(red: 0.91, green: 0.86, blue: 1.0)
        }

        var other: QuizKind { self == .pre ? .post : .pre }
    }

    enum QuestionSource: Int, Codable {
        case fromPackage = 1
        case pickedFromBank = 2
        case createdInline = 3

        var chipTitle: String {
            switch self {
            case .fromPackage:    return "From package"
            case .pickedFromBank: return "From bank"
            case .createdInline:  return "Created here"
            }
        }
    }

    enum OptionType: String, CaseIterable, Identifiable {
        case single = "SingleSelection"
        case multiple = "MultipleSelection"

        var id: String { rawValue }
        var title: String { self == .single ? "Single selection" : "Multiple selection" }
        var shortTitle: String { self == .single ? "Single" : "Multiple" }

        /// Unknown values fall back to single — every objective bank question is one of the two.
        init(apiValue: String?) {
            self = OptionType(rawValue: apiValue ?? "") ?? .single
        }
    }

    enum Difficulty: String, CaseIterable, Identifiable {
        case simple = "Simple"
        case difficult = "Difficult"
        case tough = "Tough"

        var id: String { rawValue }
    }

    // MARK: - Quiz responses

    struct ScheduleQuizzes: Decodable {
        let scheduleId: Int?
        let preQuiz: QuizSummary?
        let postQuiz: QuizSummary?

        func quiz(_ kind: QuizKind) -> QuizSummary? { kind == .pre ? preQuiz : postQuiz }
    }

    struct QuizSummary: Decodable, Equatable, Identifiable {
        let id: Int
        let quizTypeId: Int?
        let title: String
        let totalQuestions: Int
        let totalMarks: Double
        let passPercentage: Double?
        let durationMinutes: Int?
        let showResultToLearner: Bool
        let isPublished: Bool
        let publishedOn: String?
        let isLocked: Bool
        let attemptCount: Int

        enum CodingKeys: String, CodingKey {
            case id, quizTypeId, title, totalQuestions, totalMarks, passPercentage, durationMinutes
            case showResultToLearner, isPublished, publishedOn, isLocked, attemptCount
        }

        init(id: Int, quizTypeId: Int?, title: String, totalQuestions: Int, totalMarks: Double,
             passPercentage: Double?, durationMinutes: Int?, showResultToLearner: Bool,
             isPublished: Bool, publishedOn: String?, isLocked: Bool, attemptCount: Int) {
            self.id = id
            self.quizTypeId = quizTypeId
            self.title = title
            self.totalQuestions = totalQuestions
            self.totalMarks = totalMarks
            self.passPercentage = passPercentage
            self.durationMinutes = durationMinutes
            self.showResultToLearner = showResultToLearner
            self.isPublished = isPublished
            self.publishedOn = publishedOn
            self.isLocked = isLocked
            self.attemptCount = attemptCount
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            quizTypeId = try c.decodeIfPresent(Int.self, forKey: .quizTypeId)
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            totalQuestions = try c.decodeIfPresent(Int.self, forKey: .totalQuestions) ?? 0
            totalMarks = try c.decodeIfPresent(Double.self, forKey: .totalMarks) ?? 0
            passPercentage = try c.decodeIfPresent(Double.self, forKey: .passPercentage)
            durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
            showResultToLearner = try c.decodeIfPresent(Bool.self, forKey: .showResultToLearner) ?? true
            isPublished = try c.decodeIfPresent(Bool.self, forKey: .isPublished) ?? false
            publishedOn = try c.decodeIfPresent(String.self, forKey: .publishedOn)
            isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
            attemptCount = try c.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 0
        }
    }

    struct QuizDetail: Decodable {
        let summary: QuizSummary
        let scheduleId: Int?
        let instructions: String?
        let packages: [QuizPackageCard]
        let questions: [QuizQuestion]

        enum CodingKeys: String, CodingKey { case scheduleId, instructions, packages, questions }

        init(summary: QuizSummary, scheduleId: Int?, instructions: String?,
             packages: [QuizPackageCard], questions: [QuizQuestion]) {
            self.summary = summary
            self.scheduleId = scheduleId
            self.instructions = instructions
            self.packages = packages
            self.questions = questions
        }

        init(from decoder: Decoder) throws {
            summary = try QuizSummary(from: decoder)
            let c = try decoder.container(keyedBy: CodingKeys.self)
            scheduleId = try c.decodeIfPresent(Int.self, forKey: .scheduleId)
            instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
            packages = try c.decodeIfPresent([QuizPackageCard].self, forKey: .packages) ?? []
            questions = try c.decodeIfPresent([QuizQuestion].self, forKey: .questions) ?? []
        }
    }

    struct QuizPackageCard: Decodable {
        let packageId: Int
        let packageName: String?
        let packageExists: Bool
        let questionCount: Int
        let totalMarks: Double
        let questions: [QuizQuestion]

        enum CodingKeys: String, CodingKey {
            case packageId, packageName, packageExists, questionCount, totalMarks, questions
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            packageId = try c.decode(Int.self, forKey: .packageId)
            packageName = try c.decodeIfPresent(String.self, forKey: .packageName)
            packageExists = try c.decodeIfPresent(Bool.self, forKey: .packageExists) ?? true
            questionCount = try c.decodeIfPresent(Int.self, forKey: .questionCount) ?? 0
            totalMarks = try c.decodeIfPresent(Double.self, forKey: .totalMarks) ?? 0
            questions = try c.decodeIfPresent([QuizQuestion].self, forKey: .questions) ?? []
        }
    }

    struct QuizQuestion: Decodable {
        let id: Int?
        let assessmentQuestionId: Int
        let sourceTypeId: Int?
        let questionText: String?
        let optionType: String?
        let difficultyLevel: String?
        let marks: Double
    }

    struct QuizSaveResult: Decodable {
        let id: Int?
        let totalQuestions: Int?
        let totalMarks: Double?
        let messages: [String]?
    }

    // MARK: - Quiz requests

    /// Body for both create and the settings part of save.
    struct CreateQuizPayload: Encodable, Equatable {
        let quizTypeId: Int
        let title: String
        let instructions: String?
        let passPercentage: Double?
        let durationMinutes: Int?
        let showResultToLearner: Bool

        // Explicit nulls: blank pass % / duration mean "no pass mark" / "untimed".
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(quizTypeId, forKey: .quizTypeId)
            try c.encode(title, forKey: .title)
            try c.encode(instructions, forKey: .instructions)
            try c.encode(passPercentage, forKey: .passPercentage)
            try c.encode(durationMinutes, forKey: .durationMinutes)
            try c.encode(showResultToLearner, forKey: .showResultToLearner)
        }

        enum CodingKeys: String, CodingKey {
            case quizTypeId, title, instructions, passPercentage, durationMinutes, showResultToLearner
        }
    }

    struct SaveQuizPayload: Encodable, Equatable {
        struct DirectQuestion: Encodable, Equatable {
            let assessmentQuestionId: Int
            let isCreatedInline: Bool
        }

        let title: String
        let instructions: String?
        let passPercentage: Double?
        let durationMinutes: Int?
        let showResultToLearner: Bool
        let packageIds: [Int]
        let questions: [DirectQuestion]

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(title, forKey: .title)
            try c.encode(instructions, forKey: .instructions)
            try c.encode(passPercentage, forKey: .passPercentage)
            try c.encode(durationMinutes, forKey: .durationMinutes)
            try c.encode(showResultToLearner, forKey: .showResultToLearner)
            try c.encode(packageIds, forKey: .packageIds)
            try c.encode(questions, forKey: .questions)
        }

        enum CodingKeys: String, CodingKey {
            case title, instructions, passPercentage, durationMinutes, showResultToLearner
            case packageIds, questions
        }
    }

    // MARK: - Bank picker

    struct BankQuestionsPayload: Encodable {
        let page: Int
        let pageSize: Int
        let search: String?
        let difficultyLevel: String?
        let optionType: String?
        let quizId: Int?
    }

    struct BankQuestion: Decodable, Identifiable, Equatable {
        let id: Int
        let questionText: String?
        let optionType: String?
        let section: String?
        let difficultyLevel: String?
        let marks: Double
        let optionsCount: Int
        let alreadyAdded: Bool

        enum CodingKeys: String, CodingKey {
            case id, questionText, optionType, section, difficultyLevel, marks, optionsCount, alreadyAdded
        }

        init(id: Int, questionText: String?, optionType: String?, section: String?,
             difficultyLevel: String?, marks: Double, optionsCount: Int, alreadyAdded: Bool) {
            self.id = id
            self.questionText = questionText
            self.optionType = optionType
            self.section = section
            self.difficultyLevel = difficultyLevel
            self.marks = marks
            self.optionsCount = optionsCount
            self.alreadyAdded = alreadyAdded
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            questionText = try c.decodeIfPresent(String.self, forKey: .questionText)
            optionType = try c.decodeIfPresent(String.self, forKey: .optionType)
            section = try c.decodeIfPresent(String.self, forKey: .section)
            difficultyLevel = try c.decodeIfPresent(String.self, forKey: .difficultyLevel)
            marks = try c.decodeIfPresent(Double.self, forKey: .marks) ?? 0
            optionsCount = try c.decodeIfPresent(Int.self, forKey: .optionsCount) ?? 0
            alreadyAdded = try c.decodeIfPresent(Bool.self, forKey: .alreadyAdded) ?? false
        }
    }

    // MARK: - Inline question

    struct InlineQuestionPayload: Encodable, Equatable {
        struct Option: Encodable, Equatable {
            let optionText: String
            let isCorrectAnswer: Bool
        }

        let questionText: String
        let optionType: String
        let marks: Int
        let difficultyLevel: String?
        let learnerInstruction: String?
        let options: [Option]
    }

    // MARK: - Packages

    struct PackagesPayload: Encodable {
        let page: Int
        let pageSize: Int
        let search: String?
        let status: Bool
    }

    struct PackageListItem: Decodable, Identifiable, Equatable {
        let id: Int
        let packageName: String
        let description: String?
        let questionCount: Int
        let unavailableQuestionCount: Int
        let totalMarks: Double

        enum CodingKeys: String, CodingKey {
            case id, packageName, description, questionCount, unavailableQuestionCount, totalMarks
        }

        init(id: Int, packageName: String, description: String?, questionCount: Int,
             unavailableQuestionCount: Int, totalMarks: Double) {
            self.id = id
            self.packageName = packageName
            self.description = description
            self.questionCount = questionCount
            self.unavailableQuestionCount = unavailableQuestionCount
            self.totalMarks = totalMarks
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            packageName = try c.decodeIfPresent(String.self, forKey: .packageName) ?? ""
            description = try c.decodeIfPresent(String.self, forKey: .description)
            questionCount = try c.decodeIfPresent(Int.self, forKey: .questionCount) ?? 0
            unavailableQuestionCount = try c.decodeIfPresent(Int.self, forKey: .unavailableQuestionCount) ?? 0
            totalMarks = try c.decodeIfPresent(Double.self, forKey: .totalMarks) ?? 0
        }
    }

    struct PackageDetail: Decodable {
        struct Question: Decodable {
            let assessmentQuestionId: Int
            let questionText: String?
            let optionType: String?
            let difficultyLevel: String?
            let marks: Double
            let isAvailable: Bool?
        }

        let id: Int
        let packageName: String?
        let questions: [Question]
    }
}

// MARK: - Formatting

extension Double {
    /// "2" for whole marks, "2.5" otherwise. The API sends `2.00`.
    var marksText: String {
        let rounded = (self * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%g", rounded)
    }

    /// "1 mark", "2.5 marks"
    var marksLabel: String { self == 1 ? "1 mark" : "\(marksText) marks" }
}

extension Int {
    var questionsLabel: String { self == 1 ? "1 question" : "\(self) questions" }
}

extension ScheduleQuizDataModel.QuizSummary {
    var passText: String { passPercentage.map { "\($0.marksText)%" } ?? "—" }
    var durationText: String { durationMinutes.map { "\($0) min" } ?? "Untimed" }
}
