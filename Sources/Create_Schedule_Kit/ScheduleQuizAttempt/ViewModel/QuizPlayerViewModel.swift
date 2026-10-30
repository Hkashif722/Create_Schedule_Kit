//
//  QuizPlayerViewModel.swift
//  Create_Schedule_Kit
//
//  Drives one attempt: Start (also resume), question navigation, answer saves, the countdown
//  and Submit. The server owns the clock and the answers; this side only mirrors them.
//
//  Saves go one at a time through `QuizAnswerSaveQueue`, and only on Next / Previous / palette
//  jump / Exit / Submit, never per tick. Each save sends the question's whole ticked set.
//

import Foundation
import Combine
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class QuizPlayerViewModel: BaseViewModel {

    typealias DM = ScheduleQuizAttemptDataModel

    enum Phase: Equatable {
        case starting
        case failed(message: String, canRetry: Bool)
        case playing
        case finished(DM.AttemptResult)
    }

    // MARK: - Navigation Model
    let navModel: NavigationViewModel.LearnerQuizPlayerNavModel

    // MARK: - Published State
    @Published private(set) var phase: Phase = .starting
    @Published private(set) var questions: [DM.PlayerQuestion] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var sheet = DM.AnswerSheet()
    @Published private(set) var secondsLeft: Int?
    @Published private(set) var isTimeUp = false
    @Published private(set) var isSubmitting = false
    /// Start answered "already taken": the failure screen offers the result instead of a dead end.
    @Published private(set) var canViewResult = false

    // MARK: - Private
    private var attemptID: Int?
    private var countdown = DM.Countdown()
    private var timerCancellable: AnyCancellable?
    private let saveQueue = QuizAnswerSaveQueue()
    /// One key per Submit tap, kept across failed tries so a retry can't double-submit.
    private var submitKey: String?
    /// The server said the attempt no longer takes answers (409 on Answer).
    private var answersClosed = false
    private var didRetryOpenElsewhere = false
    private var isStarting = false
    private var didClose = false

    // MARK: - Init
    init(router: AnyRouter, navModel: NavigationViewModel.LearnerQuizPlayerNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }

    deinit { timerCancellable?.cancel() }
}

// MARK: - Derived UI state
extension QuizPlayerViewModel {

    var currentQuestion: DM.PlayerQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var isFirstQuestion: Bool { currentIndex == 0 }
    var isLastQuestion: Bool { currentIndex >= questions.count - 1 }
    var answeredCount: Int { sheet.answeredCount(in: questions) }
    var unansweredCount: Int { max(0, questions.count - answeredCount) }

    var acceptsAnswers: Bool { !isTimeUp && !isSubmitting && !answersClosed }

    var positionText: String { "Question \(currentIndex + 1) of \(questions.count)" }
    var answeredText: String { "\(answeredCount) answered" }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(questions.count)
    }

    var marksText: String {
        guard let marks = currentQuestion?.marks else { return "" }
        return marks.marksLabel
    }

    var timerText: String? { secondsLeft.map(DM.Countdown.clockText) }
    var isTimeLow: Bool { (secondsLeft ?? .max) < 60 }

    /// The last question, or any question once time is up, offers Submit instead of Next.
    var showsSubmit: Bool { isLastQuestion || isTimeUp || answersClosed }

    func isSelected(_ optionID: Int) -> Bool {
        guard let question = currentQuestion else { return false }
        return sheet.selected(question.attemptQuestionId).contains(optionID)
    }

    func isAnswered(at index: Int) -> Bool {
        guard questions.indices.contains(index) else { return false }
        return sheet.isAnswered(questions[index].attemptQuestionId)
    }
}

// MARK: - Lifecycle
extension QuizPlayerViewModel {

    func onAppear() {
        guard phase == .starting, attemptID == nil, !isStarting else { return }
        Task { [weak self] in await self?.startAttempt() }
    }

    func didTapRetryStart() {
        phase = .starting
        Task { [weak self] in await self?.startAttempt() }
    }
}

// MARK: - Actions
extension QuizPlayerViewModel {

    func didSelectOption(_ option: DM.PlayerOption) {
        guard acceptsAnswers, let question = currentQuestion else { return }
        sheet.toggle(optionID: option.id, in: question)
    }

    func didTapNext() {
        move(to: currentIndex + 1)
    }

    func didTapPrevious() {
        move(to: currentIndex - 1)
    }

    func didSelectQuestion(at index: Int) {
        move(to: index)
    }

    func didTapSubmit() {
        guard !isSubmitting else { return }
        // Time's up: no point asking, the server won't take more answers anyway.
        guard unansweredCount > 0, !isTimeUp, !answersClosed else {
            startSubmit()
            return
        }
        let count = unansweredCount
        presentLearnerQuizAlert(
            title: "Submit quiz?",
            message: "You have \(count) unanswered question\(count == 1 ? "" : "s"). Unanswered questions score zero, and you can't change answers after submitting.",
            alertType: .warning,
            primaryTitle: "Submit",
            secondaryTitle: "Keep answering",
            onPrimary: { [weak self] in
                // the clock may have auto-submitted while the popup sat there
                guard let self, self.phase == .playing, !self.isSubmitting else { return }
                self.startSubmit()
            }
        )
    }

    func didTapExit() {
        guard phase == .playing else {
            close()
            return
        }
        presentLearnerQuizAlert(
            title: "Exit Quiz?",
            message: "You have answered \(answeredCount) of \(questions.count) questions. Your answers so far are saved. You can resume later.",
            alertType: .warning,
            primaryTitle: "Exit Quiz",
            secondaryTitle: "Continue Quiz",
            onPrimary: { [weak self] in
                guard let self, self.phase == .playing, !self.isSubmitting else { return }
                Task { [weak self] in await self?.exitAfterSaving() }
            }
        )
    }

    /// After time-up only the time-up path can still resend dirty answers, so a retry goes
    /// through it too.
    private func startSubmit() {
        Task { [weak self] in
            guard let self else { return }
            if self.isTimeUp {
                await self.submitAfterTimeUp()
            } else {
                await self.submit()
            }
        }
    }

    func didTapDone() {
        close()
    }

    func didTapViewResult() {
        close()
        navModel.onViewResult?()
    }

    private func move(to index: Int) {
        guard questions.indices.contains(index), index != currentIndex else { return }
        // the one being left, plus any earlier save that failed
        saveAllPending()
        currentIndex = index
    }

    private func close() {
        guard !didClose else { return }
        didClose = true
        stopTimer()
        router.dismissScreen()
        navModel.onClose()
    }
}

// MARK: - API
extension QuizPlayerViewModel {

    @MainActor
    private func startAttempt() async {
        isStarting = true
        defer { isStarting = false }
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: DM.StartResponse.self,
                model: DM.StartAttemptRequest(quizID: navModel.quizID),
                payload: ScheduleQuizDataModel.EmptyBody()
            )
            guard !response.questions.isEmpty else {
                phase = .failed(message: DM.StartFailure.noQuestions.message, canRetry: false)
                return
            }
            attemptID = response.attemptId
            questions = response.questions
            sheet = DM.AnswerSheet(questions: response.questions)
            currentIndex = response.startIndex
            phase = .playing
            if let remaining = response.remainingSeconds {
                countdown.reset(remainingSeconds: remaining)
                startTimer()
            }
        } catch {
            await handleStartFailure(error)
        }
    }

    @MainActor
    private func handleStartFailure(_ error: Error) async {
        guard let apiError = AssessmentAPIError(error) else {
            reportLearnerQuizError(error, resetLoadingState: true)
            phase = .failed(message: "We couldn't open this quiz. Please try again.", canRetry: true)
            return
        }
        let failure = DM.StartFailure(apiError)
        // Open in another window: the spec says just call Start again. Once.
        if failure == .openElsewhere, !didRetryOpenElsewhere {
            didRetryOpenElsewhere = true
            await startAttempt()
            return
        }
        let message = failure == .other ? apiError.message(fallback: failure.message) : failure.message
        canViewResult = failure == .alreadyTaken && navModel.onViewResult != nil
        phase = .failed(message: message, canRetry: failure == .other || failure == .openElsewhere)
    }

    /// Every question whose ticks differ from what the server has, not just the current one —
    /// a save that failed earlier would otherwise only retry if the learner went back to it.
    private func saveAllPending(afterTimeUp: Bool = false) {
        for index in questions.indices { saveQuestion(at: index, afterTimeUp: afterTimeUp) }
    }

    private var hasUnsavedAnswers: Bool {
        questions.contains { sheet.needsSave($0.attemptQuestionId) }
    }

    /// Queues a save for the question at `index` if its ticks changed since the last save.
    /// `afterTimeUp` lets the final flush past the time-up flag that blocks normal saves.
    private func saveQuestion(at index: Int, afterTimeUp: Bool = false) {
        let canSave = afterTimeUp ? !isSubmitting && !answersClosed : acceptsAnswers
        guard let attemptID, canSave, questions.indices.contains(index) else { return }
        let questionID = questions[index].attemptQuestionId
        guard sheet.needsSave(questionID) else { return }
        let optionIDs = sheet.beginSave(questionID)
        saveQueue.enqueue { [weak self] in
            await self?.postAnswer(attemptID: attemptID, questionID: questionID, optionIDs: optionIDs)
        }
    }

    @MainActor
    private func postAnswer(attemptID: Int, questionID: Int, optionIDs: [Int]) async {
        guard !answersClosed else {
            sheet.finishSave(questionID, optionIDs: optionIDs, succeeded: false)
            return
        }
        do {
            let response = try await ApiService.shared.requestPostHeader(
                type: DM.AnswerResponse.self,
                model: DM.SaveAnswerRequest(attemptID: attemptID),
                payload: DM.AnswerPayload(attemptQuestionId: questionID, optionIds: optionIDs)
            )
            sheet.finishSave(questionID, optionIDs: optionIDs, succeeded: true)
            if let remaining = response.remainingSeconds, !isTimeUp {
                countdown.reset(remainingSeconds: remaining)
                tick()
            }
        } catch {
            sheet.finishSave(questionID, optionIDs: optionIDs, succeeded: false)
            handleAnswerFailure(error)
        }
    }

    @MainActor
    private func handleAnswerFailure(_ error: Error) {
        guard let apiError = AssessmentAPIError(error) else {
            // Network blip: the question stays dirty and goes again on the next move.
            reportLearnerQuizError(error, resetLoadingState: false)
            return
        }
        switch DM.AnswerFailure(apiError) {
        case .closed:
            answersClosed = true
            // Not awaited: submit drains this very queue, and we're running inside it.
            if !isSubmitting {
                Task { [weak self] in await self?.submit(isAuto: true) }
            }
        case .attemptGone:
            stopTimer()
            phase = .failed(message: "This attempt is no longer available.", canRetry: false)
        case .rejected(let message):
            toast = Toast(style: .error, message: message)
        case .other:
            reportLearnerQuizError(error, resetLoadingState: false)
        }
    }

    @MainActor
    private func submit(isAuto: Bool = false) async {
        guard !isSubmitting, let attemptID else { return }
        // Flush everything unsaved before the flag closes the door on saves.
        saveAllPending()
        isSubmitting = true
        loadingState = .loading(message: isAuto ? "Time's up. Submitting your answers..." : "Submitting...")
        await saveQueue.drain()

        // A manual submit over answers the server never got would score them as blank. Time-up
        // submits anyway: the server stops taking answers at zero regardless.
        if !isAuto, !answersClosed, hasUnsavedAnswers {
            isSubmitting = false
            loadingState = .none
            toast = Toast(style: .error, message: "Some answers couldn't be saved. Check your connection and tap Submit again.")
            return
        }

        let key = submitKey ?? UUID().uuidString.lowercased()
        submitKey = key
        do {
            let result = try await ApiService.shared.requestPostHeader(
                type: DM.AttemptResult.self,
                model: DM.SubmitAttemptRequest(attemptID: attemptID),
                payload: DM.SubmitPayload(idempotencyKey: key)
            )
            finish(with: result)
        } catch {
            await handleSubmitFailure(error, attemptID: attemptID)
        }
    }

    @MainActor
    private func handleSubmitFailure(_ error: Error, attemptID: Int) async {
        guard let apiError = AssessmentAPIError(error) else {
            isSubmitting = false
            reportLearnerQuizError(error)
            return
        }
        switch DM.SubmitFailure(apiError) {
        case .alreadySubmitted:
            await fetchResult(attemptID: attemptID)
        case .notFound:
            loadingState = .none
            stopTimer()
            phase = .failed(message: "This attempt is no longer available.", canRetry: false)
        case .other:
            isSubmitting = false
            reportLearnerQuizError(error)
        }
    }

    @MainActor
    private func fetchResult(attemptID: Int) async {
        do {
            let result = try await ApiService.shared.requestGetHeader(
                type: DM.AttemptResult.self,
                model: DM.GetResultRequest(attemptID: attemptID)
            )
            finish(with: result)
        } catch {
            loadingState = .none
            stopTimer()
            phase = .failed(message: "Your quiz was submitted, but the result couldn't be loaded. Check the quiz card for your score.", canRetry: false)
        }
    }

    @MainActor
    private func finish(with result: DM.AttemptResult) {
        stopTimer()
        submitKey = nil
        isSubmitting = false
        loadingState = .none
        phase = .finished(result)
    }

    @MainActor
    private func exitAfterSaving() async {
        guard phase == .playing else {
            close()
            return
        }
        let wasAccepting = acceptsAnswers
        loadingState = .loading(message: "Saving your answers...")
        saveAllPending()
        await saveQueue.drain()
        // time-up or a 409 started the auto-submit mid-drain; it owns the overlay and lands on the result
        if wasAccepting, !acceptsAnswers, phase == .playing { return }
        loadingState = .none
        guard phase == .playing else { return }
        if acceptsAnswers, hasUnsavedAnswers {
            presentLearnerQuizAlert(
                title: "Answers not saved",
                message: "Some answers couldn't be saved. Check your connection and try again, or exit without them.",
                alertType: .warning,
                primaryTitle: "Try again",
                secondaryTitle: "Exit anyway",
                onPrimary: { [weak self] in
                    Task { [weak self] in await self?.exitAfterSaving() }
                },
                onSecondary: { [weak self] in self?.close() }
            )
            return
        }
        close()
    }
}

// MARK: - Countdown
extension QuizPlayerViewModel {

    private func startTimer() {
        tick()
        guard timerCancellable == nil, countdown.isTimed else { return }
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tick() {
        guard countdown.isTimed else { return }
        secondsLeft = countdown.secondsLeft()
        if secondsLeft == 0 { handleTimeUp() }
    }

    private func handleTimeUp() {
        guard !isTimeUp else { return }
        isTimeUp = true
        stopTimer()
        guard phase == .playing else { return }
        Task { [weak self] in await self?.submitAfterTimeUp() }
    }

    /// `submit` would skip every dirty question because the time-up flag already blocks
    /// saves, so they all go in here first.
    @MainActor
    private func submitAfterTimeUp() async {
        saveAllPending(afterTimeUp: true)
        await submit(isAuto: true)
    }
}
