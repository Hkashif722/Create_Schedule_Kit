//
//  QuizEditorViewModel.swift
//  Create_Schedule_Kit
//
//  One quiz: settings, attached packages, direct questions. Everything is local until Save,
//  which posts the full state and reloads. Mobile has no separate Publish button, so a saved
//  draft with questions is published right after the save — otherwise learners never see it.
//
//  Locked (a learner opened it): only title, instructions and result visibility may change,
//  and the server 409s a save that touches anything else, so those controls are disabled.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class QuizEditorViewModel: BaseViewModel {

    typealias DM = ScheduleQuizDataModel

    struct SaveBanner: Equatable {
        let title: String
        let messages: [String]
    }

    let navModel: NavigationViewModel.QuizEditorNavModel

    @Published private(set) var summary: DM.QuizSummary?
    @Published private(set) var draft: QuizDraft?
    @Published private(set) var saveBanner: SaveBanner?
    @Published private(set) var expandedPackageIDs: Set<Int> = []
    @Published private(set) var loadFailed = false
    @Published private(set) var isSaving = false

    /// What the last load/save left on the server — the "unsaved changes" baseline.
    private var baseline: DM.SaveQuizPayload?
    private var hasPromptedOtherQuiz = false

    init(router: AnyRouter, navModel: NavigationViewModel.QuizEditorNavModel) {
        self.navModel = navModel
        super.init(router: router)
    }
}

// MARK: - Derived state
extension QuizEditorViewModel {

    var kind: DM.QuizKind { navModel.kind }

    var headerTitle: String {
        guard let title = draft?.settings.title, !title.isEmpty else { return kind.shortTitle }
        return "\(kind.shortTitle) · \(title)"
    }

    var isLocked: Bool { summary?.isLocked ?? false }
    var isPublished: Bool { summary?.isPublished ?? false }

    var hasUnsavedChanges: Bool {
        guard let draft, let baseline else { return false }
        return draft.savePayload != baseline
    }

    var totals: QuizDraft.Totals { draft?.estimatedTotals ?? .init(questions: 0, marks: 0) }

    /// A saved draft that already has questions only needs the publish half of Save.
    private var needsPublish: Bool { !isPublished && totals.questions > 0 }

    var canSave: Bool { draft != nil && !isSaving && (hasUnsavedChanges || needsPublish) }

    /// "6 questions · 43 marks · pass at 60%"
    var totalsText: String {
        let t = totals
        let questions = t.questions.questionsLabel
        let pass = draft?.settings.passPercentage.map { "pass at \($0.marksText)%" } ?? "no pass mark"
        return "\(questions) · \(t.marks.marksLabel) · \(pass)"
    }

    var attemptsText: String? {
        guard let count = summary?.attemptCount, count > 0 else { return nil }
        return count == 1 ? "1 attempt" : "\(count) attempts"
    }

    /// Numbering runs packages first, then the direct list, the way the server serves them.
    func startIndex(ofPackageAt offset: Int) -> Int {
        (draft?.packages ?? []).prefix(offset)
            .reduce(0) { $0 + ($1.isPreviewLoaded ? $1.questions.count : $1.questionCount) }
    }

    var directStartIndex: Int { startIndex(ofPackageAt: draft?.packages.count ?? 0) }
}

// MARK: - Load
extension QuizEditorViewModel {

    func onAppear() {
        guard draft == nil, !loadingState.isLoading else { return }
        Task { [weak self] in await self?.load(showsLoader: true) }
    }

    func didTapRetry() {
        Task { [weak self] in await self?.load(showsLoader: true) }
    }

    @MainActor
    private func load(showsLoader: Bool) async {
        if showsLoader { loadingState = .loading(message: "Loading quiz...") }
        do {
            let detail = try await ApiService.shared.requestGetHeader(
                type: DM.QuizDetail.self,
                model: DM.GetQuizRequest(quizID: navModel.quizID)
            )
            apply(detail)
            loadFailed = false
            loadingState = .none
        } catch {
            loadFailed = draft == nil
            handleQuizError(error, fallback: "Could not load the quiz.")
        }
    }

    private func apply(_ detail: DM.QuizDetail) {
        let fresh = QuizDraft(detail: detail)
        summary = detail.summary
        draft = fresh
        baseline = fresh.savePayload
        expandedPackageIDs = expandedPackageIDs.intersection(fresh.attachedPackageIDs)
    }
}

// MARK: - Editing actions
extension QuizEditorViewModel {

    func didTapEditSettings() {
        guard let draft else { return }
        let navModel = NavigationViewModel.QuizSettingsNavModel(
            kind: kind,
            mode: .edit,
            initial: QuizSettingsDataModel.Form(settings: draft.settings),
            isLocked: isLocked,
            onDone: { [weak self] outcome in
                guard case .applied(let settings) = outcome else { return }
                self?.draft?.settings = settings
            },
            onCancel: {}
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.quizSettings(navModel))
    }

    func didTapAddPackage() {
        guard let draft, !isLocked else { return }
        let navModel = NavigationViewModel.QuizPackagePickerNavModel(
            attachedIDs: draft.attachedPackageIDs,
            onAdd: { [weak self] packages in
                guard let self else { return }
                self.draft?.attach(packages)
                Task { [weak self] in await self?.loadPreviews(packageIDs: packages.map(\.id)) }
            }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.quizPackagePicker(navModel))
    }

    func didTapPickFromBank() {
        guard let draft, !isLocked else { return }
        let navModel = NavigationViewModel.QuizBankPickerNavModel(
            quizID: self.navModel.quizID,
            blockedIDs: draft.blockedBankQuestionIDs,
            onAdd: { [weak self] picks in
                self?.draft?.add(picks.map(QuizDraft.Question.init(bankQuestion:)))
            }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.quizBankPicker(navModel))
    }

    func didTapWriteNew() {
        guard draft != nil, !isLocked else { return }
        let navModel = NavigationViewModel.QuizInlineQuestionNavModel(
            onSaved: { [weak self] question in
                self?.draft?.add([question])
                self?.toast = Toast(style: .success, message: "Question saved to the bank. Tap Save to add it to the quiz.")
            }
        )
        NavigationService.shared.navigate(using: router, to: AppNavigationDestination.quizInlineQuestion(navModel))
    }

    func didTapRemovePackage(_ id: Int) {
        guard !isLocked else { return }
        draft?.removePackage(id: id)
        expandedPackageIDs.remove(id)
    }

    func didTapRemoveQuestion(_ id: Int) {
        guard !isLocked else { return }
        draft?.removeQuestion(id: id)
    }

    func toggleExpanded(_ id: Int) {
        if expandedPackageIDs.contains(id) {
            expandedPackageIDs.remove(id)
        } else {
            expandedPackageIDs.insert(id)
        }
    }

    func didTapBack() {
        guard hasUnsavedChanges else {
            router.dismissScreen()
            return
        }
        let model = CustomAlertPopupModel(
            title: "Discard changes?",
            alertType: .warning,
            content: {
                Text("Your changes to this quiz haven't been saved.")
                    .multilineTextAlignment(.center)
                    .padding()
            },
            primaryButtonTitle: "Discard",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
                self?.router.dismissScreen()
            },
            secondaryButtonTitle: "Keep editing",
            secondaryAction: { [weak self] in self?.router.dismissModal() }
        )
        showPopup(model)
    }

    /// Package previews are best-effort: a failed fetch keeps the list-row counts and says so
    /// on the card instead of spinning.
    @MainActor
    private func loadPreviews(packageIDs: [Int]) async {
        let results = await withTaskGroup(of: (Int, DM.PackageDetail?).self) { group -> [(Int, DM.PackageDetail?)] in
            for id in packageIDs {
                group.addTask {
                    let detail = try? await ApiService.shared.requestGetHeader(
                        type: DM.PackageDetail.self,
                        model: DM.GetPackageRequest(packageID: id)
                    )
                    return (id, detail)
                }
            }
            var collected: [(Int, DM.PackageDetail?)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        guard !Task.isCancelled else { return }
        for (id, detail) in results {
            if let detail {
                draft?.applyPreview(detail)
            } else {
                draft?.markPreviewFailed(packageID: id)
            }
        }
    }
}

// MARK: - Save
extension QuizEditorViewModel {

    func didTapSave() {
        guard canSave, let draft else { return }
        if isPublished, totals.questions == 0 {
            toast = Toast(style: .warning, message: "A published quiz must keep at least one question.")
            return
        }
        let payload = draft.savePayload
        let saveFirst = hasUnsavedChanges
        Task { [weak self] in await self?.save(payload: payload, saveFirst: saveFirst) }
    }

    /// Save and publish are separate calls: once the save lands, a failed publish must not
    /// read as a failed save — the editor still reloads, the slots still refresh and the
    /// server's save notes still show. Save stays enabled so the publish can be retried.
    @MainActor
    private func save(payload: DM.SaveQuizPayload, saveFirst: Bool) async {
        isSaving = true
        defer { isSaving = false }
        loadingState = .loading(message: "Saving quiz...")

        let questionSetChanged = payload.packageIds != baseline?.packageIds || payload.questions != baseline?.questions
        var messages: [String] = []
        var savedCount = totals.questions
        if saveFirst {
            do {
                let result = try await ApiService.shared.requestPostHeader(
                    type: DM.QuizSaveResult.self,
                    model: DM.SaveQuizRequest(quizID: navModel.quizID),
                    payload: payload
                )
                messages = (result.messages ?? []).filter { !$0.isEmpty }
                savedCount = result.totalQuestions ?? savedCount
            } catch {
                handleQuizError(error, fallback: "Could not save the quiz.")
                return
            }
        }

        var didPublish = false
        var publishError: Error?
        if !isPublished, savedCount > 0 {
            do {
                _ = try await ApiService.shared.requestPostHeader(
                    type: DM.IDResponse.self,
                    model: DM.PublishQuizRequest(quizID: navModel.quizID),
                    payload: DM.EmptyBody()
                )
                didPublish = true
            } catch {
                publishError = error
            }
        }

        await load(showsLoader: false)
        loadingState = .none
        navModel.onChanged()

        let t = totals
        let head = didPublish ? "Saved & published" : (publishError == nil ? "Saved" : "Saved, not published")
        saveBanner = SaveBanner(
            title: "\(head) · \(t.questions.questionsLabel) · \(t.marks.marksLabel)",
            messages: messages
        )
        if let publishError {
            let reason = AssessmentAPIError(publishError)?.message(fallback: "") ?? ""
            toast = Toast(
                style: .error,
                message: reason.isEmpty ? "Saved, but the quiz couldn't be published. Tap Save to try again." : reason
            )
        }
        afterSave(messages: messages,
                  questionCount: t.questions,
                  promptsOther: saveFirst && questionSetChanged && publishError == nil)
    }

    /// The server's save notes must be acknowledged (dropped duplicates, removed questions,
    /// changed marks). Then, once, the Figma prompt to set up the other slot — only after a
    /// save that actually changed the questions, not a settings-only one.
    @MainActor
    private func afterSave(messages: [String], questionCount: Int, promptsOther wantsPrompt: Bool) {
        let promptsOther = wantsPrompt && questionCount > 0 && !hasPromptedOtherQuiz && navModel.isOtherSlotEmpty()
        guard !messages.isEmpty else {
            if promptsOther { promptOtherQuiz(questionCount: questionCount) }
            return
        }
        let model = CustomAlertPopupModel(
            title: "Quiz saved",
            alertType: .info,
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messages, id: \.self) { message in
                        Text("• \(message)").fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            },
            primaryButtonTitle: "OK",
            primaryAction: { [weak self] in
                self?.router.dismissModal()
                guard promptsOther else { return }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    self?.promptOtherQuiz(questionCount: questionCount)
                }
            }
        )
        showPopup(model)
    }

    @MainActor
    private func promptOtherQuiz(questionCount: Int) {
        hasPromptedOtherQuiz = true
        let other = kind.other
        let model = CustomAlertPopupModel(
            title: "Questions Added Successfully!",
            alertType: .success,
            content: {
                QuizAddOtherPromptContent(kind: kind, questionCount: questionCount)
            },
            primaryButtonTitle: other == .post ? "Yes, Add Post Quiz" : "Yes, Add Pre Quiz",
            primaryAction: { [weak self] in
                guard let self else { return }
                self.router.dismissModal()
                self.router.dismissScreen()
                self.navModel.onAddOtherQuiz()
            },
            secondaryButtonTitle: "No, Skip",
            secondaryAction: { [weak self] in self?.router.dismissModal() }
        )
        showPopup(model)
    }
}

// MARK: - Helpers
extension QuizEditorViewModel {

    private func showPopup(_ model: CustomAlertPopupModel) {
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.packageDestination(.customAlertPopupView(model))
        )
    }

    @MainActor
    private func handleQuizError(_ error: Error, fallback: String) {
        guard let apiError = AssessmentAPIError(error) else {
            handleAPIError((error as? APIError)?.toUIError() ?? error, resetLoadingState: true, showToast: true)
            return
        }
        loadingState = .none
        switch apiError.statusCode {
        case 409:
            toast = Toast(style: .error, message: "Learners have started this quiz. Questions, marks, pass % and duration can no longer change.")
            Task { [weak self] in await self?.load(showsLoader: false) }
        case 404:
            toast = Toast(style: .error, message: "This quiz no longer exists.")
            navModel.onChanged()
        default:
            toast = Toast(style: .error, message: apiError.message(fallback: fallback))
        }
    }
}
