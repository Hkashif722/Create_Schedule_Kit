//
//  ScheduleQuizAttemptTests.swift
//  Create_Schedule_KitTests
//
//  Learner quiz (`ILTScheduleQuizAttempt`): routes, bodies, DTO decoding against the spec's
//  shapes, card states, the answer sheet's save bookkeeping, the countdown, error mapping and
//  the one-at-a-time save queue.
//

import Foundation
import NetworkService
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleQuizAttemptTests {

    typealias DM = ScheduleQuizAttemptDataModel

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func encodeToObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func question(_ id: Int, sort: Int = 1, multiple: Bool = false, selected: [Int] = []) -> DM.PlayerQuestion {
        DM.PlayerQuestion(
            attemptQuestionId: id, sortOrder: sort, questionText: "Q\(id)",
            optionType: multiple ? .multiple : .single, marks: 1,
            isAnswered: !selected.isEmpty, selectedOptionIds: selected,
            options: [.init(id: id * 10 + 1, optionText: "A"), .init(id: id * 10 + 2, optionText: "B"),
                      .init(id: id * 10 + 3, optionText: "C")]
        )
    }

    // MARK: - Routes

    @Test func routesMatchTheLearnerController() {
        #expect(DM.GetQuizCardsRequest(scheduleID: 482).path == "/api/v1/ILTScheduleQuizAttempt/Schedule/482")
        #expect(DM.GetQuizCardsRequest(scheduleID: 482).method == .get)
        #expect(DM.StartAttemptRequest(quizID: 31).path == "/api/v1/ILTScheduleQuizAttempt/Quiz/31/Start")
        #expect(DM.StartAttemptRequest(quizID: 31).method == .post)
        #expect(DM.SaveAnswerRequest(attemptID: 7).path == "/api/v1/ILTScheduleQuizAttempt/7/Answer")
        #expect(DM.SaveAnswerRequest(attemptID: 7).method == .post)
        #expect(DM.SubmitAttemptRequest(attemptID: 7).path == "/api/v1/ILTScheduleQuizAttempt/7/Submit")
        #expect(DM.SubmitAttemptRequest(attemptID: 7).method == .post)
        #expect(DM.GetResultRequest(attemptID: 7).path == "/api/v1/ILTScheduleQuizAttempt/7/Result")
        #expect(DM.GetResultRequest(attemptID: 7).method == .get)
    }

    @Test func answerBodySendsTheFullTickedSet() throws {
        let body = try encodeToObject(DM.AnswerPayload(attemptQuestionId: 901, optionIds: [3, 5]))
        #expect(body["attemptQuestionId"] as? Int == 901)
        #expect(body["optionIds"] as? [Int] == [3, 5])

        let cleared = try encodeToObject(DM.AnswerPayload(attemptQuestionId: 901, optionIds: []))
        #expect(cleared["optionIds"] as? [Int] == [])
    }

    @Test func submitBodyCarriesTheIdempotencyKey() throws {
        let body = try encodeToObject(DM.SubmitPayload(idempotencyKey: "3f1c"))
        #expect(body.keys.sorted() == ["idempotencyKey"])
        #expect(body["idempotencyKey"] as? String == "3f1c")
    }

    // MARK: - Cards

    private let cardsJSON = """
    {
      "scheduleId": 482,
      "preQuiz": {
        "quizId": 31, "quizTypeId": 1, "quizType": "PreQuiz", "title": "Fire safety — Pre quiz",
        "instructions": null, "totalQuestions": 10, "totalMarks": 14.00, "passPercentage": 60.00,
        "durationMinutes": 15, "isEligible": true, "ineligibleReason": null, "state": "InProgress",
        "attemptId": 77, "attemptsRemaining": 1, "remainingSeconds": 540, "score": null
      },
      "postQuiz": null
    }
    """

    @Test func cardsDecodeAndNullSlotsDisappear() throws {
        let cards = try decode(DM.ScheduleQuizCards.self, cardsJSON)
        let pre = try #require(cards.preQuiz)
        #expect(pre.quizId == 31)
        #expect(pre.totalMarks == 14)
        #expect(pre.passPercentage == 60)
        #expect(pre.state == .inProgress)
        #expect(pre.attemptId == 77)
        #expect(cards.postQuiz == nil)

        let slots = cards.slots
        #expect(slots.map(\.kind) == [.pre])
    }

    @Test func slotsKeepPreBeforePost() throws {
        let json = """
        {"preQuiz": {"quizId": 1, "state": "NotStarted", "isEligible": true},
         "postQuiz": {"quizId": 2, "state": "Submitted", "isEligible": true}}
        """
        let slots = try decode(DM.ScheduleQuizCards.self, json).slots
        #expect(slots.map(\.kind) == [.pre, .post])
        #expect(slots.map(\.card.quizId) == [1, 2])
    }

    @Test func anUnknownStateReadsAsNotStarted() throws {
        let card = try decode(DM.QuizCard.self, #"{"quizId": 1, "state": "Archived", "isEligible": true}"#)
        #expect(card.state == .notStarted)
    }

    @Test func ineligibilityWinsOverState() throws {
        let card = try decode(DM.QuizCard.self, """
        {"quizId": 1, "state": "NotStarted", "isEligible": false,
         "ineligibleReason": "Attendance must be marked Completed."}
        """)
        #expect(card.status == .ineligible(reason: "Attendance must be marked Completed."))

        let blank = try decode(DM.QuizCard.self, #"{"quizId": 1, "state": "InProgress", "isEligible": false, "ineligibleReason": "  "}"#)
        #expect(blank.status == .ineligible(reason: "You can't take this quiz right now."))
    }

    @Test func cardStatusFollowsTheAttemptState() throws {
        let inProgress = try decode(DM.QuizCard.self, #"{"quizId": 1, "state": "InProgress", "isEligible": true, "remainingSeconds": 90}"#)
        #expect(inProgress.status == .inProgress(remainingSeconds: 90))

        let hidden = try decode(DM.QuizCard.self, #"{"quizId": 1, "state": "Submitted", "isEligible": true, "score": null}"#)
        #expect(hidden.status == .submitted(score: nil))

        let scored = try decode(DM.QuizCard.self, """
        {"quizId": 1, "state": "Submitted", "isEligible": true,
         "score": {"totalMarks": 10, "obtainedMarks": 6, "percentage": 60, "isPassed": true,
                   "correctCount": 3, "wrongCount": 2, "unansweredCount": 0}}
        """)
        guard case .submitted(let score?) = scored.status else {
            Issue.record("expected a submitted card with a score")
            return
        }
        #expect(score.obtainedMarks == 6)
        #expect(score.isPassed == true)
    }

    @Test func untimedAndNoPassMarkRenderAsDashes() throws {
        let card = try decode(DM.QuizCard.self, #"{"quizId": 1, "state": "NotStarted", "isEligible": true}"#)
        #expect(card.passText == "—")
        #expect(card.durationText == "Untimed")
    }

    // MARK: - Start

    private let startJSON = """
    {
      "attemptId": 77, "quizId": 31, "quizTypeId": 1, "quizType": "PreQuiz", "title": "Pre",
      "instructions": null, "totalQuestions": 3, "totalMarks": 3, "durationMinutes": 10,
      "remainingSeconds": 412, "isResumed": true, "resumeAttemptQuestionId": 902,
      "questions": [
        {"attemptQuestionId": 903, "sortOrder": 3, "questionText": "Third", "optionType": "MultipleSelection",
         "marks": 1.00, "isAnswered": false, "selectedOptionIds": [], "options": [{"id": 1, "optionText": "a", "optionMediaFile": null}]},
        {"attemptQuestionId": 901, "sortOrder": 1, "questionText": "First", "optionType": "SingleSelection",
         "marks": 2.00, "isAnswered": true, "selectedOptionIds": [11], "options": [{"id": 11, "optionText": "x"}, {"id": 12, "optionText": "y"}]},
        {"attemptQuestionId": 902, "sortOrder": 2, "questionText": "Second", "optionType": "SingleSelection",
         "marks": 1.00, "isAnswered": false, "selectedOptionIds": [], "options": [{"id": 21, "optionText": "p"}]}
      ]
    }
    """

    @Test func startSortsQuestionsAndResumesAtTheServerPointer() throws {
        let start = try decode(DM.StartResponse.self, startJSON)
        #expect(start.questions.map(\.attemptQuestionId) == [901, 902, 903])
        #expect(start.startIndex == 1)
        #expect(start.remainingSeconds == 412)
        #expect(start.questions[2].isMultiple)
        #expect(start.questions[0].marks == 2)
    }

    @Test func anUnknownResumePointerOpensAtTheTop() throws {
        let json = startJSON.replacingOccurrences(of: "\"resumeAttemptQuestionId\": 902", with: "\"resumeAttemptQuestionId\": 5")
        #expect(try decode(DM.StartResponse.self, json).startIndex == 0)
    }

    @Test func resumedTicksArePreSelected() throws {
        let start = try decode(DM.StartResponse.self, startJSON)
        let sheet = DM.AnswerSheet(questions: start.questions)
        #expect(sheet.selected(901) == [11])
        #expect(sheet.answeredCount(in: start.questions) == 1)
        // Pre-ticked from the server, so nothing to save until it changes.
        #expect(!sheet.needsSave(901))
    }

    // MARK: - Answer sheet

    @Test func singleSelectionReplacesAndKeepsOnRetap() {
        let q = question(1)
        var sheet = DM.AnswerSheet(questions: [q])
        sheet.toggle(optionID: 11, in: q)
        sheet.toggle(optionID: 12, in: q)
        #expect(sheet.selected(1) == [12])
        sheet.toggle(optionID: 12, in: q)
        #expect(sheet.selected(1) == [12])
    }

    @Test func multipleSelectionToggles() {
        let q = question(2, multiple: true)
        var sheet = DM.AnswerSheet(questions: [q])
        sheet.toggle(optionID: 21, in: q)
        sheet.toggle(optionID: 23, in: q)
        #expect(sheet.selected(2) == [21, 23])
        sheet.toggle(optionID: 21, in: q)
        #expect(sheet.selected(2) == [23])
    }

    @Test func aChangedQuestionNeedsOneSaveUntilAcknowledged() {
        let q = question(1)
        var sheet = DM.AnswerSheet(questions: [q])
        #expect(!sheet.needsSave(1))

        sheet.toggle(optionID: 11, in: q)
        #expect(sheet.needsSave(1))

        let sent = sheet.beginSave(1)
        #expect(sent == [11])
        // In flight: a second Next must not queue the same set again.
        #expect(!sheet.needsSave(1))

        sheet.finishSave(1, optionIDs: sent, succeeded: true)
        #expect(!sheet.needsSave(1))
    }

    @Test func aFailedSaveLeavesTheQuestionDirty() {
        let q = question(1)
        var sheet = DM.AnswerSheet(questions: [q])
        sheet.toggle(optionID: 12, in: q)
        let sent = sheet.beginSave(1)
        sheet.finishSave(1, optionIDs: sent, succeeded: false)
        #expect(sheet.needsSave(1))
    }

    @Test func untickingAnAnsweredQuestionSavesAnEmptySet() {
        let q = question(3, multiple: true, selected: [31])
        var sheet = DM.AnswerSheet(questions: [q])
        sheet.toggle(optionID: 31, in: q)
        #expect(sheet.needsSave(3))
        #expect(sheet.beginSave(3) == [])
        #expect(!sheet.isAnswered(3))
    }

    @Test func editingWhileASaveIsInFlightQueuesTheNewSet() {
        let q = question(2, multiple: true)
        var sheet = DM.AnswerSheet(questions: [q])
        sheet.toggle(optionID: 21, in: q)
        let first = sheet.beginSave(2)
        sheet.toggle(optionID: 22, in: q)
        #expect(sheet.needsSave(2))
        let second = sheet.beginSave(2)
        #expect(second == [21, 22])
        // The older reply lands after the newer send: it must not clear the newer one's flag.
        sheet.finishSave(2, optionIDs: first, succeeded: true)
        #expect(!sheet.needsSave(2))
        sheet.finishSave(2, optionIDs: second, succeeded: true)
        #expect(!sheet.needsSave(2))
    }

    // MARK: - Countdown

    @Test func countdownRunsFromTheServerValue() {
        let now = Date(timeIntervalSince1970: 1_000)
        var countdown = DM.Countdown()
        #expect(!countdown.isTimed)
        #expect(countdown.secondsLeft(now: now) == nil)

        countdown.reset(remainingSeconds: 90, now: now)
        #expect(countdown.secondsLeft(now: now) == 90)
        #expect(countdown.secondsLeft(now: now.addingTimeInterval(30.4)) == 60)
        #expect(countdown.secondsLeft(now: now.addingTimeInterval(500)) == 0)

        // A later Answer reply resets it, whatever the local clock thought.
        countdown.reset(remainingSeconds: 75, now: now.addingTimeInterval(20))
        #expect(countdown.secondsLeft(now: now.addingTimeInterval(20)) == 75)
    }

    @Test func clockTextPadsMinutesAndShowsHours() {
        #expect(DM.Countdown.clockText(0) == "00:00")
        #expect(DM.Countdown.clockText(245) == "04:05")
        #expect(DM.Countdown.clockText(3_723) == "1:02:03")
        #expect(DM.Countdown.clockText(-5) == "00:00")
    }

    @Test func optionLettersRunAlphabetically() {
        #expect(DM.optionLetter(0) == "A")
        #expect(DM.optionLetter(3) == "D")
        #expect(DM.optionLetter(26) == "27")
    }

    // MARK: - Errors

    private func apiError(_ status: Int, _ code: String?) -> AssessmentAPIError {
        AssessmentAPIError(statusCode: status, code: code, description: nil)
    }

    @Test func startFailuresFollowTheSpecTable() {
        #expect(DM.StartFailure(apiError(404, "NotFound")) == .notFound)
        #expect(DM.StartFailure(apiError(409, "AttemptExist")) == .alreadyTaken)
        #expect(DM.StartFailure(apiError(403, "NoAccess")) == .noAccess)
        #expect(DM.StartFailure(apiError(409, "InvalidRequest")) == .noQuestions)
        #expect(DM.StartFailure(apiError(409, "AssessmentInProgress")) == .openElsewhere)
        #expect(DM.StartFailure(apiError(400, "InternalServerError")) == .other)
    }

    @Test func startFailuresSurviveTheNetworkLayer() throws {
        // NetworkService hands 409 back as serverError carrying only `message`.
        let wrapped = try #require(AssessmentAPIError(APIError.serverError(statusCode: 409, message: "AttemptExist")))
        #expect(DM.StartFailure(wrapped) == .alreadyTaken)
    }

    @Test func answerFailuresDecideWhetherToSubmit() {
        #expect(DM.AnswerFailure(apiError(409, "InvalidRequest")) == .closed)
        #expect(DM.AnswerFailure(apiError(404, "NotFound")) == .attemptGone)
        #expect(DM.AnswerFailure(AssessmentAPIError(statusCode: 400, code: "InvalidData",
                                                    description: "Options don't belong to the question."))
                == .rejected("Options don't belong to the question."))
        #expect(DM.AnswerFailure(apiError(500, nil)) == .other)
    }

    @Test func submitAndResultFailures() {
        #expect(DM.SubmitFailure(apiError(409, "InvalidRequest")) == .alreadySubmitted)
        #expect(DM.SubmitFailure(apiError(404, "NotFound")) == .notFound)
        #expect(DM.ResultFailure(apiError(409, "NotCompleted")) == .notCompleted)
        #expect(DM.ResultFailure(apiError(404, "NotFound")) == .notFound)
    }

    // MARK: - Result

    @Test func visibleResultDecodesWithReview() throws {
        let json = """
        {
          "attemptId": 77, "quizId": 31, "quizTypeId": 1, "quizType": "PreQuiz", "title": "Pre",
          "submittedOn": "29-10-2026", "timeTakenSeconds": 245, "passPercentage": 60, "resultVisible": true,
          "score": {"totalMarks": 10, "obtainedMarks": 4, "percentage": 40, "isPassed": false,
                    "correctCount": 2, "wrongCount": 2, "unansweredCount": 1},
          "questions": [
            {"attemptQuestionId": 2, "sortOrder": 2, "questionText": "B?", "optionType": "SingleSelection",
             "marksAllotted": 2, "marksObtained": 0, "isAnswered": true, "isCorrect": false,
             "options": [{"id": 1, "optionText": "No", "optionMediaFile": null, "isCorrect": false, "isSelected": true},
                         {"id": 2, "optionText": "Yes", "optionMediaFile": null, "isCorrect": true, "isSelected": false}]},
            {"attemptQuestionId": 1, "sortOrder": 1, "questionText": "A?", "optionType": "SingleSelection",
             "marksAllotted": 2, "marksObtained": 2, "isAnswered": true, "isCorrect": true,
             "options": [{"id": 3, "optionText": "Right", "isCorrect": true, "isSelected": true}]}
          ]
        }
        """
        let result = try decode(DM.AttemptResult.self, json)
        #expect(result.outcome == .failed)
        #expect(result.questions.map(\.attemptQuestionId) == [1, 2])
        #expect(result.questions[1].selectedText == "No")
        #expect(result.questions[1].correctText == "Yes")
        #expect(result.score?.unansweredCount == 1)
    }

    @Test func hiddenResultIsConfirmationOnly() throws {
        let json = #"{"attemptId": 77, "resultVisible": false, "score": null, "questions": null}"#
        let result = try decode(DM.AttemptResult.self, json)
        #expect(result.outcome == .hidden)
        #expect(result.questions.isEmpty)
    }

    @Test func noPassMarkMeansNoBadge() throws {
        let json = """
        {"resultVisible": true, "passPercentage": null,
         "score": {"totalMarks": 5, "obtainedMarks": 5, "percentage": 100, "isPassed": null,
                   "correctCount": 5, "wrongCount": 0, "unansweredCount": 0}}
        """
        #expect(try decode(DM.AttemptResult.self, json).outcome == .neutral)
    }

    @Test func passedOutcome() throws {
        let json = """
        {"resultVisible": true,
         "score": {"totalMarks": 10, "obtainedMarks": 6, "percentage": 60, "isPassed": true,
                   "correctCount": 3, "wrongCount": 2, "unansweredCount": 0}}
        """
        #expect(try decode(DM.AttemptResult.self, json).outcome == .passed)
    }

    // MARK: - Save queue

    @Test func saveQueueRunsOneAtATimeInOrder() async {
        actor Log {
            var events: [String] = []
            func add(_ event: String) { events.append(event) }
        }
        let log = Log()
        let queue = QuizAnswerSaveQueue()
        for (index, delay) in [(1, 30), (2, 1), (3, 10)] {
            queue.enqueue {
                await log.add("start \(index)")
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
                await log.add("end \(index)")
            }
        }
        await queue.drain()
        #expect(await log.events == ["start 1", "end 1", "start 2", "end 2", "start 3", "end 3"])
    }

    @Test func drainingAnEmptyQueueReturns() async {
        await QuizAnswerSaveQueue().drain()
    }
}
