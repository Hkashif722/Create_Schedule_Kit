//
//  ScheduleQuizAttemptDataModel.swift
//  Create_Schedule_Kit
//
//  Learner side of the schedule Pre/Post quiz (`ILTScheduleQuizAttempt`). Every call acts on
//  the signed-in learner's own attempts; the user id rides in the token.
//
//   • Schedule/{scheduleId}     GET  → ScheduleQuizCards
//   • Quiz/{quizId}/Start       POST → StartResponse  (also resumes an open attempt)
//   • {attemptId}/Answer        POST → AnswerResponse (full ticked set, [] clears)
//   • {attemptId}/Submit        POST → AttemptResult  (idempotency key per Submit tap)
//   • {attemptId}/Result        GET  → AttemptResult
//
//  Also holds the player's bookkeeping as plain value types (answer sheet, countdown, save
//  queue, error mapping) so the rules are testable without a router.
//

import Foundation
import NetworkService

enum ScheduleQuizAttemptDataModel {

    typealias QuizKind = ScheduleQuizDataModel.QuizKind
    typealias OptionType = ScheduleQuizDataModel.OptionType

    // MARK: - Endpoints

    private static func attemptPath(_ segments: String...) -> String {
        ([APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.iltScheduleQuizAttempt] + segments)
            .joined(separator: "/")
    }

    struct GetQuizCardsRequest: EndpointModel {
        let scheduleID: Int
        var path: String { ScheduleQuizAttemptDataModel.attemptPath(APIConst.scheduleSegment, "\(scheduleID)") }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    /// Start doubles as resume, and the first Start locks the quiz for the manager. Never call
    /// it just to preview.
    struct StartAttemptRequest: EndpointModel {
        let quizID: Int
        var path: String {
            ScheduleQuizAttemptDataModel.attemptPath(APIConst.quizSegment, "\(quizID)", APIConst.start)
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    struct SaveAnswerRequest: EndpointModel {
        let attemptID: Int
        var path: String { ScheduleQuizAttemptDataModel.attemptPath("\(attemptID)", APIConst.answer) }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    struct SubmitAttemptRequest: EndpointModel {
        let attemptID: Int
        var path: String { ScheduleQuizAttemptDataModel.attemptPath("\(attemptID)", APIConst.submit) }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }
    }

    struct GetResultRequest: EndpointModel {
        let attemptID: Int
        var path: String { ScheduleQuizAttemptDataModel.attemptPath("\(attemptID)", APIConst.result) }
        var method: HTTPMethod { .get }
        var headers: [String: String]? { nil }
    }

    // MARK: - Payloads

    struct AnswerPayload: Encodable, Equatable {
        let attemptQuestionId: Int
        let optionIds: [Int]
    }

    struct SubmitPayload: Encodable, Equatable {
        let idempotencyKey: String
    }

    // MARK: - Cards

    enum AttemptState: String, Decodable {
        case notStarted = "NotStarted"
        case inProgress = "InProgress"
        case submitted = "Submitted"

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = AttemptState(rawValue: raw) ?? .notStarted
        }
    }

    struct Score: Decodable, Equatable {
        let totalMarks: Double
        let obtainedMarks: Double
        let percentage: Double
        /// Nil when the quiz has no pass mark. Hide the pass/fail badge then.
        let isPassed: Bool?
        let correctCount: Int
        let wrongCount: Int
        let unansweredCount: Int

        enum CodingKeys: String, CodingKey {
            case totalMarks, obtainedMarks, percentage, isPassed, correctCount, wrongCount, unansweredCount
        }

        init(totalMarks: Double, obtainedMarks: Double, percentage: Double, isPassed: Bool?,
             correctCount: Int, wrongCount: Int, unansweredCount: Int) {
            self.totalMarks = totalMarks
            self.obtainedMarks = obtainedMarks
            self.percentage = percentage
            self.isPassed = isPassed
            self.correctCount = correctCount
            self.wrongCount = wrongCount
            self.unansweredCount = unansweredCount
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            totalMarks = try c.decodeIfPresent(Double.self, forKey: .totalMarks) ?? 0
            obtainedMarks = try c.decodeIfPresent(Double.self, forKey: .obtainedMarks) ?? 0
            percentage = try c.decodeIfPresent(Double.self, forKey: .percentage) ?? 0
            isPassed = try c.decodeIfPresent(Bool.self, forKey: .isPassed)
            correctCount = try c.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
            wrongCount = try c.decodeIfPresent(Int.self, forKey: .wrongCount) ?? 0
            unansweredCount = try c.decodeIfPresent(Int.self, forKey: .unansweredCount) ?? 0
        }
    }

    struct ScheduleQuizCards: Decodable {
        let scheduleId: Int?
        let preQuiz: QuizCard?
        let postQuiz: QuizCard?

        func card(_ kind: QuizKind) -> QuizCard? { kind == .pre ? preQuiz : postQuiz }
    }

    struct QuizCard: Decodable, Equatable {
        let quizId: Int
        let quizTypeId: Int?
        let title: String
        let instructions: String?
        let totalQuestions: Int
        let totalMarks: Double
        let passPercentage: Double?
        /// Nil = untimed.
        let durationMinutes: Int?
        let isEligible: Bool
        let ineligibleReason: String?
        let state: AttemptState
        let attemptId: Int?
        let attemptsRemaining: Int
        /// Only while InProgress and timed.
        let remainingSeconds: Int?
        /// Only once Submitted and the manager shows results.
        let score: Score?

        enum CodingKeys: String, CodingKey {
            case quizId, quizTypeId, title, instructions, totalQuestions, totalMarks, passPercentage
            case durationMinutes, isEligible, ineligibleReason, state, attemptId, attemptsRemaining
            case remainingSeconds, score
        }

        init(quizId: Int, quizTypeId: Int?, title: String, instructions: String?, totalQuestions: Int,
             totalMarks: Double, passPercentage: Double?, durationMinutes: Int?, isEligible: Bool,
             ineligibleReason: String?, state: AttemptState, attemptId: Int?, attemptsRemaining: Int,
             remainingSeconds: Int?, score: Score?) {
            self.quizId = quizId
            self.quizTypeId = quizTypeId
            self.title = title
            self.instructions = instructions
            self.totalQuestions = totalQuestions
            self.totalMarks = totalMarks
            self.passPercentage = passPercentage
            self.durationMinutes = durationMinutes
            self.isEligible = isEligible
            self.ineligibleReason = ineligibleReason
            self.state = state
            self.attemptId = attemptId
            self.attemptsRemaining = attemptsRemaining
            self.remainingSeconds = remainingSeconds
            self.score = score
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            quizId = try c.decode(Int.self, forKey: .quizId)
            quizTypeId = try c.decodeIfPresent(Int.self, forKey: .quizTypeId)
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
            totalQuestions = try c.decodeIfPresent(Int.self, forKey: .totalQuestions) ?? 0
            totalMarks = try c.decodeIfPresent(Double.self, forKey: .totalMarks) ?? 0
            passPercentage = try c.decodeIfPresent(Double.self, forKey: .passPercentage)
            durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
            isEligible = try c.decodeIfPresent(Bool.self, forKey: .isEligible) ?? false
            ineligibleReason = try c.decodeIfPresent(String.self, forKey: .ineligibleReason)
            state = try c.decodeIfPresent(AttemptState.self, forKey: .state) ?? .notStarted
            attemptId = try c.decodeIfPresent(Int.self, forKey: .attemptId)
            attemptsRemaining = try c.decodeIfPresent(Int.self, forKey: .attemptsRemaining) ?? 0
            remainingSeconds = try c.decodeIfPresent(Int.self, forKey: .remainingSeconds)
            score = try c.decodeIfPresent(Score.self, forKey: .score)
        }
    }

    /// What a card offers. Eligibility wins over state, so a blocked learner never sees Start.
    enum CardStatus: Equatable {
        case ineligible(reason: String)
        case notStarted
        case inProgress(remainingSeconds: Int?)
        /// `score` is nil when the manager hides results.
        case submitted(score: Score?)
    }

    // MARK: - Player

    struct PlayerOption: Decodable, Identifiable, Equatable {
        let id: Int
        let optionText: String
        let optionMediaFile: String?

        enum CodingKeys: String, CodingKey { case id, optionText, optionMediaFile }

        init(id: Int, optionText: String, optionMediaFile: String? = nil) {
            self.id = id
            self.optionText = optionText
            self.optionMediaFile = optionMediaFile
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            optionText = try c.decodeIfPresent(String.self, forKey: .optionText) ?? ""
            optionMediaFile = try c.decodeIfPresent(String.self, forKey: .optionMediaFile)
        }
    }

    struct PlayerQuestion: Decodable, Identifiable, Equatable {
        /// Use this in Answer, never the bank id.
        let attemptQuestionId: Int
        let sortOrder: Int
        let questionText: String
        let learnerInstruction: String?
        let optionType: OptionType
        let marks: Double
        let isAnswered: Bool
        let selectedOptionIds: [Int]
        let options: [PlayerOption]

        var id: Int { attemptQuestionId }
        var isMultiple: Bool { optionType == .multiple }

        enum CodingKeys: String, CodingKey {
            case attemptQuestionId, sortOrder, questionText, learnerInstruction, optionType, marks
            case isAnswered, selectedOptionIds, options
        }

        init(attemptQuestionId: Int, sortOrder: Int, questionText: String, learnerInstruction: String? = nil,
             optionType: OptionType, marks: Double, isAnswered: Bool = false,
             selectedOptionIds: [Int] = [], options: [PlayerOption]) {
            self.attemptQuestionId = attemptQuestionId
            self.sortOrder = sortOrder
            self.questionText = questionText
            self.learnerInstruction = learnerInstruction
            self.optionType = optionType
            self.marks = marks
            self.isAnswered = isAnswered
            self.selectedOptionIds = selectedOptionIds
            self.options = options
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            attemptQuestionId = try c.decode(Int.self, forKey: .attemptQuestionId)
            sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
            questionText = try c.decodeIfPresent(String.self, forKey: .questionText) ?? ""
            learnerInstruction = try c.decodeIfPresent(String.self, forKey: .learnerInstruction)
            optionType = OptionType(apiValue: try c.decodeIfPresent(String.self, forKey: .optionType))
            marks = try c.decodeIfPresent(Double.self, forKey: .marks) ?? 0
            isAnswered = try c.decodeIfPresent(Bool.self, forKey: .isAnswered) ?? false
            selectedOptionIds = try c.decodeIfPresent([Int].self, forKey: .selectedOptionIds) ?? []
            options = try c.decodeIfPresent([PlayerOption].self, forKey: .options) ?? []
        }
    }

    struct StartResponse: Decodable {
        let attemptId: Int
        let quizId: Int?
        let title: String?
        let instructions: String?
        let totalQuestions: Int?
        let totalMarks: Double?
        let durationMinutes: Int?
        let remainingSeconds: Int?
        let isResumed: Bool?
        /// First unanswered question, or the last one when all are answered.
        let resumeAttemptQuestionId: Int?
        let questions: [PlayerQuestion]

        enum CodingKeys: String, CodingKey {
            case attemptId, quizId, title, instructions, totalQuestions, totalMarks, durationMinutes
            case remainingSeconds, isResumed, resumeAttemptQuestionId, questions
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            attemptId = try c.decode(Int.self, forKey: .attemptId)
            quizId = try c.decodeIfPresent(Int.self, forKey: .quizId)
            title = try c.decodeIfPresent(String.self, forKey: .title)
            instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
            totalQuestions = try c.decodeIfPresent(Int.self, forKey: .totalQuestions)
            totalMarks = try c.decodeIfPresent(Double.self, forKey: .totalMarks)
            durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
            remainingSeconds = try c.decodeIfPresent(Int.self, forKey: .remainingSeconds)
            isResumed = try c.decodeIfPresent(Bool.self, forKey: .isResumed)
            resumeAttemptQuestionId = try c.decodeIfPresent(Int.self, forKey: .resumeAttemptQuestionId)
            questions = (try c.decodeIfPresent([PlayerQuestion].self, forKey: .questions) ?? [])
                .sorted { $0.sortOrder < $1.sortOrder }
        }

        /// Where to open: the server's resume pointer when it names a known question, else the top.
        var startIndex: Int {
            guard let resumeAttemptQuestionId,
                  let index = questions.firstIndex(where: { $0.attemptQuestionId == resumeAttemptQuestionId })
            else { return 0 }
            return index
        }
    }

    struct AnswerResponse: Decodable {
        let attemptQuestionId: Int?
        let isAnswered: Bool?
        let remainingSeconds: Int?
    }

    // MARK: - Result

    struct ResultOption: Decodable, Identifiable, Equatable {
        let id: Int
        let optionText: String
        let isCorrect: Bool
        let isSelected: Bool

        enum CodingKeys: String, CodingKey { case id, optionText, isCorrect, isSelected }

        init(id: Int, optionText: String, isCorrect: Bool, isSelected: Bool) {
            self.id = id
            self.optionText = optionText
            self.isCorrect = isCorrect
            self.isSelected = isSelected
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            optionText = try c.decodeIfPresent(String.self, forKey: .optionText) ?? ""
            isCorrect = try c.decodeIfPresent(Bool.self, forKey: .isCorrect) ?? false
            isSelected = try c.decodeIfPresent(Bool.self, forKey: .isSelected) ?? false
        }
    }

    struct ResultQuestion: Decodable, Identifiable, Equatable {
        let attemptQuestionId: Int
        let sortOrder: Int
        let questionText: String
        let marksAllotted: Double
        let marksObtained: Double
        let isAnswered: Bool
        let isCorrect: Bool
        let options: [ResultOption]

        var id: Int { attemptQuestionId }

        enum CodingKeys: String, CodingKey {
            case attemptQuestionId, sortOrder, questionText, marksAllotted, marksObtained
            case isAnswered, isCorrect, options
        }

        init(attemptQuestionId: Int, sortOrder: Int, questionText: String, marksAllotted: Double,
             marksObtained: Double, isAnswered: Bool, isCorrect: Bool, options: [ResultOption]) {
            self.attemptQuestionId = attemptQuestionId
            self.sortOrder = sortOrder
            self.questionText = questionText
            self.marksAllotted = marksAllotted
            self.marksObtained = marksObtained
            self.isAnswered = isAnswered
            self.isCorrect = isCorrect
            self.options = options
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            attemptQuestionId = try c.decode(Int.self, forKey: .attemptQuestionId)
            sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
            questionText = try c.decodeIfPresent(String.self, forKey: .questionText) ?? ""
            marksAllotted = try c.decodeIfPresent(Double.self, forKey: .marksAllotted) ?? 0
            marksObtained = try c.decodeIfPresent(Double.self, forKey: .marksObtained) ?? 0
            isAnswered = try c.decodeIfPresent(Bool.self, forKey: .isAnswered) ?? false
            isCorrect = try c.decodeIfPresent(Bool.self, forKey: .isCorrect) ?? false
            options = try c.decodeIfPresent([ResultOption].self, forKey: .options) ?? []
        }

        var selectedText: String? {
            let picked = options.filter(\.isSelected).map(\.optionText)
            return picked.isEmpty ? nil : picked.joined(separator: ", ")
        }

        var correctText: String {
            options.filter(\.isCorrect).map(\.optionText).joined(separator: ", ")
        }
    }

    struct AttemptResult: Decodable, Equatable {
        let attemptId: Int?
        let quizId: Int?
        let title: String?
        /// Already in the app's date format. Shown as is.
        let submittedOn: String?
        let timeTakenSeconds: Int?
        let passPercentage: Double?
        let resultVisible: Bool
        let score: Score?
        let questions: [ResultQuestion]

        enum CodingKeys: String, CodingKey {
            case attemptId, quizId, title, submittedOn, timeTakenSeconds, passPercentage
            case resultVisible, score, questions
        }

        init(attemptId: Int?, quizId: Int?, title: String?, submittedOn: String?, timeTakenSeconds: Int?,
             passPercentage: Double?, resultVisible: Bool, score: Score?, questions: [ResultQuestion]) {
            self.attemptId = attemptId
            self.quizId = quizId
            self.title = title
            self.submittedOn = submittedOn
            self.timeTakenSeconds = timeTakenSeconds
            self.passPercentage = passPercentage
            self.resultVisible = resultVisible
            self.score = score
            self.questions = questions
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            attemptId = try c.decodeIfPresent(Int.self, forKey: .attemptId)
            quizId = try c.decodeIfPresent(Int.self, forKey: .quizId)
            title = try c.decodeIfPresent(String.self, forKey: .title)
            submittedOn = try c.decodeIfPresent(String.self, forKey: .submittedOn)
            timeTakenSeconds = try c.decodeIfPresent(Int.self, forKey: .timeTakenSeconds)
            passPercentage = try c.decodeIfPresent(Double.self, forKey: .passPercentage)
            score = try c.decodeIfPresent(Score.self, forKey: .score)
            // A missing flag with a score present still means "visible".
            resultVisible = try c.decodeIfPresent(Bool.self, forKey: .resultVisible) ?? (score != nil)
            questions = (try c.decodeIfPresent([ResultQuestion].self, forKey: .questions) ?? [])
                .sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    enum ResultOutcome: Equatable {
        case passed, failed
        /// No pass mark set: no badge, just the numbers.
        case neutral
        /// Manager hid results: confirmation only.
        case hidden
    }
}

// MARK: - Card mapping

/// One visible card. A null slot never becomes one.
struct LearnerQuizSlot: Identifiable, Equatable {
    let kind: ScheduleQuizDataModel.QuizKind
    let card: ScheduleQuizAttemptDataModel.QuizCard

    var id: Int { kind.rawValue }
}

extension ScheduleQuizAttemptDataModel.ScheduleQuizCards {

    /// Pre before Post, null slots dropped.
    var slots: [LearnerQuizSlot] {
        ScheduleQuizDataModel.QuizKind.allCases.compactMap { kind in
            card(kind).map { LearnerQuizSlot(kind: kind, card: $0) }
        }
    }
}

extension ScheduleQuizAttemptDataModel.QuizCard {

    var status: ScheduleQuizAttemptDataModel.CardStatus {
        if !isEligible {
            let reason = ineligibleReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .ineligible(reason: reason.isEmpty ? "You can't take this quiz right now." : reason)
        }
        switch state {
        case .notStarted: return .notStarted
        case .inProgress: return .inProgress(remainingSeconds: remainingSeconds)
        case .submitted:  return .submitted(score: score)
        }
    }

    var passText: String { passPercentage.map { "\($0.marksText)%" } ?? "—" }
    var durationText: String { durationMinutes.map { "\($0) min" } ?? "Untimed" }
}

extension ScheduleQuizAttemptDataModel {

    /// "A", "B", ... for option rows. Numbers past "Z", which no quiz reaches.
    static func optionLetter(_ index: Int) -> String {
        guard (0..<26).contains(index), let scalar = UnicodeScalar(65 + index) else { return "\(index + 1)" }
        return String(Character(scalar))
    }
}

extension ScheduleQuizAttemptDataModel.AttemptResult {

    var outcome: ScheduleQuizAttemptDataModel.ResultOutcome {
        guard resultVisible, let score else { return .hidden }
        switch score.isPassed {
        case .some(true):  return .passed
        case .some(false): return .failed
        case .none:        return .neutral
        }
    }
}

// MARK: - Answer sheet

extension ScheduleQuizAttemptDataModel {

    /// Ticks per question plus what the server last accepted, so the player only saves a
    /// question whose set actually changed.
    struct AnswerSheet: Equatable {

        private(set) var selections: [Int: Set<Int>] = [:]
        private var saved: [Int: Set<Int>] = [:]
        /// Sent and not yet acknowledged. Stops a double tap on Next from queueing twice.
        private var queued: [Int: Set<Int>] = [:]

        init(questions: [PlayerQuestion] = []) {
            for question in questions {
                let ids = Set(question.selectedOptionIds)
                selections[question.attemptQuestionId] = ids
                saved[question.attemptQuestionId] = ids
            }
        }

        func selected(_ questionID: Int) -> Set<Int> {
            selections[questionID] ?? []
        }

        func isAnswered(_ questionID: Int) -> Bool {
            !selected(questionID).isEmpty
        }

        func answeredCount(in questions: [PlayerQuestion]) -> Int {
            questions.filter { isAnswered($0.attemptQuestionId) }.count
        }

        /// Radio for single selection (re-tapping keeps it), checkbox for multiple.
        mutating func toggle(optionID: Int, in question: PlayerQuestion) {
            let id = question.attemptQuestionId
            if question.isMultiple {
                var current = selected(id)
                if current.contains(optionID) { current.remove(optionID) } else { current.insert(optionID) }
                selections[id] = current
            } else {
                selections[id] = [optionID]
            }
        }

        func needsSave(_ questionID: Int) -> Bool {
            let baseline = queued[questionID] ?? saved[questionID] ?? []
            return selected(questionID) != baseline
        }

        /// Marks the current ticks as in flight and hands back the body's `optionIds`.
        mutating func beginSave(_ questionID: Int) -> [Int] {
            let current = selected(questionID)
            queued[questionID] = current
            return current.sorted()
        }

        mutating func finishSave(_ questionID: Int, optionIDs: [Int], succeeded: Bool) {
            let sent = Set(optionIDs)
            if succeeded { saved[questionID] = sent }
            if queued[questionID] == sent { queued[questionID] = nil }
        }
    }

    // MARK: - Countdown

    /// Server-owned timer. The client only counts down from the last `remainingSeconds` it got.
    struct Countdown: Equatable {
        private(set) var deadline: Date?

        var isTimed: Bool { deadline != nil }

        mutating func reset(remainingSeconds: Int, now: Date = Date()) {
            deadline = now.addingTimeInterval(TimeInterval(max(0, remainingSeconds)))
        }

        mutating func stop() { deadline = nil }

        func secondsLeft(now: Date = Date()) -> Int? {
            guard let deadline else { return nil }
            return max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
        }

        /// "04:05", or "1:02:03" past an hour.
        static func clockText(_ seconds: Int) -> String {
            let s = max(0, seconds)
            let hours = s / 3600, minutes = (s % 3600) / 60, secs = s % 60
            if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    // MARK: - Errors

    enum StartFailure: Equatable {
        case notFound, alreadyTaken, noAccess, noQuestions, openElsewhere, other

        init(_ error: AssessmentAPIError) {
            switch (error.statusCode, error.code?.lowercased()) {
            case (404, _):                       self = .notFound
            case (403, _):                       self = .noAccess
            case (409, "attemptexist"):          self = .alreadyTaken
            case (409, "assessmentinprogress"):  self = .openElsewhere
            case (409, "invalidrequest"):        self = .noQuestions
            default:                             self = .other
            }
        }

        var message: String {
            switch self {
            case .notFound:      return "This quiz is no longer available."
            case .alreadyTaken:  return "You have already taken this quiz."
            case .noAccess:      return "You're not eligible to take this quiz yet."
            case .noQuestions:   return "This quiz has no questions yet. Please check back later."
            case .openElsewhere: return "This quiz is open somewhere else. Please try again."
            case .other:         return AssessmentAPIError.genericMessage
            }
        }
    }

    enum AnswerFailure: Equatable {
        /// 404: the attempt is gone. Back to the schedule.
        case attemptGone
        /// 409: already submitted or time is up. Either way stop and submit.
        case closed
        /// 400: options don't fit the question. A client bug, worth a toast.
        case rejected(String)
        case other

        init(_ error: AssessmentAPIError) {
            switch error.statusCode {
            case 404: self = .attemptGone
            case 409: self = .closed
            case 400: self = .rejected(error.message(fallback: "That answer couldn't be saved."))
            default:  self = .other
            }
        }
    }

    enum SubmitFailure: Equatable {
        case notFound
        /// 409: already submitted. Just fetch the result.
        case alreadySubmitted
        case other

        init(_ error: AssessmentAPIError) {
            switch error.statusCode {
            case 404: self = .notFound
            case 409: self = .alreadySubmitted
            default:  self = .other
            }
        }
    }

    enum ResultFailure: Equatable {
        case notFound
        /// 409 NotCompleted: the attempt is still open.
        case notCompleted
        case other

        init(_ error: AssessmentAPIError) {
            switch (error.statusCode, error.code?.lowercased()) {
            case (404, _):              self = .notFound
            case (409, "notcompleted"): self = .notCompleted
            case (409, _):              self = .notCompleted
            default:                    self = .other
            }
        }
    }
}

// MARK: - Serial save queue

/// Runs answer saves one at a time, in the order they were queued. The API wants a single
/// request in flight per attempt.
final class QuizAnswerSaveQueue {

    private var tail: Task<Void, Never>?

    func enqueue(_ operation: @escaping () async -> Void) {
        let previous = tail
        tail = Task {
            await previous?.value
            await operation()
        }
    }

    /// Waits until everything queued so far (and anything queued meanwhile) has run.
    func drain() async {
        while let current = tail {
            await current.value
            if current == tail { return }
        }
    }
}
