//
//  ScheduleLogisticsViewModel.swift
//  Create_Schedule_Kit
//
//  Step 2 logic: academy + training-place typeahead, trainer search (encrypted),
//  tags, and training-place driven auto-fill of coordinator / contact.
//

import Foundation
import SwiftfulRouting
import SwiftUIUtilities
import NetworkService

final class ScheduleLogisticsViewModel: BaseViewModel {

    // MARK: - Dependencies
    private let draft: ScheduleDraft
    /// Edit mode unlocks the coordinator (server type-ahead) and contact number fields.
    let isEditMode: Bool
    private let onBack: () -> Void
    private let onContinue: () -> Void

    // MARK: - Published State
    @Published var academyResults: [ScheduleLogisticsDataModel.Academy] = []
    @Published var selectedAcademy: ScheduleLogisticsDataModel.Academy?

    @Published var trainingPlaceResults: [ScheduleLogisticsDataModel.TrainingPlace] = []
    @Published var selectedTrainingPlace: ScheduleLogisticsDataModel.TrainingPlace?

    @Published var trainerType: TrainerType = .internal
    @Published var trainerResults: [ScheduleLogisticsDataModel.Trainer] = []
    @Published var selectedTrainers: [ScheduleLogisticsDataModel.Trainer] = []
    /// Incremented to ask the trainer search field to clear itself and take focus.
    @Published private(set) var trainerFocusToken: Int = 0
    /// Where an External trainer is coming from. `nil` means the choice is still open, which
    /// is what puts the two-option menu in place of the search field. Only consulted while
    /// `trainerType == .external`; Internal and Consultant always search the directory.
    @Published private(set) var trainerSource: TrainerSource?
    @Published var isTrainerSourceMenuOpen: Bool = false
    /// Last typed trainer keyword, kept so the search can re-run when Trainer Type changes.
    private var trainerQuery: String = ""

    @Published var allTags: [ScheduleLogisticsDataModel.Tag] = []
    @Published var selectedTags: [ScheduleLogisticsDataModel.Tag] = []

    @Published var coordinatorName: String = ""
    @Published var contactNumber: String = ""

    // Coordinator type-ahead (edit mode only).
    @Published var coordinatorResults: [ScheduleLogisticsDataModel.CoordinatorUser] = []
    @Published var selectedCoordinator: ScheduleLogisticsDataModel.CoordinatorUser?

    // MARK: - Init
    init(router: AnyRouter, draft: ScheduleDraft, isEditMode: Bool = false, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.draft = draft
        self.isEditMode = isEditMode
        self.onBack = onBack
        self.onContinue = onContinue
        super.init(router: router)
        restoreFromDraft()
    }

    func loadData() {
        // Trainers are fetched server-side per keystroke in the Trainer field
        // (see `onTrainerSearch` / `searchTrainers`), so they are not prefetched here.
        if allTags.isEmpty {
            Task { [weak self] in await self?.fetchTags() }
        }
    }

    private func restoreFromDraft() {
        selectedAcademy = draft.academy
        selectedTrainingPlace = draft.trainingPlace
        trainerType = draft.trainerType
        selectedTrainers = draft.trainers
        selectedTags = draft.tags
        coordinatorName = draft.coordinatorName
        contactNumber = draft.contactNumber
        // Show the current coordinator in the type-ahead field when editing.
        if isEditMode, !draft.coordinatorName.isEmpty {
            selectedCoordinator = ScheduleLogisticsDataModel.CoordinatorUser(
                id: "current-coordinator",
                dB_UserId: nil,
                name: draft.coordinatorName,
                emailId: nil,
                userId: nil,
                profilePicture: nil,
                mobileNumber: nil,
                userType: nil,
                nameUserId: nil,
                isDeleted: nil,
                userMasterId: nil
            )
        }
    }
}

// MARK: - Derived UI State
extension ScheduleLogisticsViewModel {

    var trainerTypeOptions: [TrainerType] { TrainerType.allCases }

    /// External trainers may not exist in the directory yet, so the field first asks where
    /// this one comes from. Every other trainer type goes straight to the search field.
    var showsTrainerSourceMenu: Bool {
        trainerType == .external && trainerSource == nil
    }

    func isTagSelected(_ tag: ScheduleLogisticsDataModel.Tag) -> Bool {
        selectedTags.contains(where: { $0.id == tag.id })
    }

    var canContinue: Bool {
        selectedTrainingPlace != nil && !selectedTrainers.isEmpty
    }
}

// MARK: - Actions
extension ScheduleLogisticsViewModel {

    func onAcademySearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { academyResults = []; return }
        Task { [weak self] in await self?.fetchAcademies(query: trimmed) }
    }

    func didSelectAcademy(_ academy: ScheduleLogisticsDataModel.Academy) {
        selectedAcademy = academy
    }

    func onTrainingPlaceSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { trainingPlaceResults = []; return }
        Task { [weak self] in await self?.fetchTrainingPlaces(query: trimmed) }
    }

    func didSelectTrainingPlace(_ place: ScheduleLogisticsDataModel.TrainingPlace) {
        selectedTrainingPlace = place
        // Coordinator / contact are auto-filled (read-only) from the place detail endpoint.
        // Clear first so stale values from a prior selection don't linger while it loads.
        coordinatorName = ""
        contactNumber = ""
        Task { [weak self] in await self?.fetchTrainingPlaceDetail(id: place.id) }
    }

    func didSelectTrainerType(_ type: TrainerType) {
        trainerType = type
        // The source question belongs to External only, and re-asking it on every switch is
        // the safe default — a source picked for a previous type says nothing about this one.
        trainerSource = nil
        isTrainerSourceMenuOpen = false
        // Results are scoped to the type, so re-search (or clear) on change.
        let query = trainerQuery
        guard query.count >= 2 else { trainerResults = []; return }
        Task { [weak self] in await self?.searchTrainers(query: query) }
    }

    func didSelectTrainerSource(_ source: TrainerSource) {
        switch source {
        case .existingUser:
            // Swaps the menu out for the usual server-side search field.
            trainerSource = .existingUser
        case .newTrainer:
            presentCreateTrainer()
        }
    }

    /// A trainer created from the sheet is treated exactly like a searched one, then the field
    /// returns to the source menu so the next trainer can come from either place.
    func didCreateTrainer(_ trainer: ScheduleLogisticsDataModel.Trainer) {
        didSelectTrainer(trainer)
        trainerSource = nil
        isTrainerSourceMenuOpen = false
        toast = Toast(style: .success, message: "\(trainer.displayName) added as a trainer.")
    }

    private func presentCreateTrainer() {
        let navModel = NavigationViewModel.CreateTrainerNavModel(
            onCreated: { [weak self] trainer in
                self?.didCreateTrainer(trainer)
            }
        )
        NavigationService.shared.navigate(
            using: router,
            to: AppNavigationDestination.createTrainer(navModel)
        )
    }

    func onTrainerSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        trainerQuery = trimmed
        guard trimmed.count >= 2 else { trainerResults = []; return }
        Task { [weak self] in await self?.searchTrainers(query: trimmed) }
    }

    func didSelectTrainer(_ trainer: ScheduleLogisticsDataModel.Trainer) {
        guard !selectedTrainers.contains(where: { $0.id == trainer.id }) else { return }
        selectedTrainers.append(trainer.withUserType(trainerType.apiValue))
    }

    func removeTrainer(_ trainer: ScheduleLogisticsDataModel.Trainer) {
        selectedTrainers.removeAll { $0.id == trainer.id }
    }

    /// Clears the trainer search field and puts the keyboard in it, ready for the next name.
    /// For External the field is the source menu instead, so this reopens that choice —
    /// the next trainer may well need creating rather than searching.
    func didTapAddAnotherTrainer() {
        if trainerType == .external {
            trainerSource = nil
            isTrainerSourceMenuOpen = true
            return
        }
        trainerFocusToken += 1
    }

    func onCoordinatorSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { coordinatorResults = []; return }
        Task { [weak self] in await self?.searchCoordinators(query: trimmed) }
    }

    func didSelectCoordinator(_ user: ScheduleLogisticsDataModel.CoordinatorUser) {
        selectedCoordinator = user
        coordinatorName = user.name
        // The searched user's mobile number arrives encrypted; the populated value
        // stays user-editable afterwards.
        let raw = user.mobileNumber ?? ""
        let decrypted = EncryptDecryptUtility.shared.newDecryptString(responseStr: raw)
        contactNumber = decrypted.isEmpty ? raw : decrypted
    }

    func toggleTag(_ tag: ScheduleLogisticsDataModel.Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }

    func didTapBack() {
        commitToDraft()
        onBack()
    }

    func didTapContinue() {
        guard canContinue else {
            toast = Toast(style: .warning, message: "Select a training place and at least one trainer.")
            return
        }
        commitToDraft()
        onContinue()
    }

    private func commitToDraft() {
        draft.academy = selectedAcademy
        draft.trainingPlace = selectedTrainingPlace
        draft.trainerType = trainerType
        draft.trainers = selectedTrainers
        draft.tags = selectedTags
        draft.coordinatorName = coordinatorName
        draft.contactNumber = contactNumber
    }
}

// MARK: - API
extension ScheduleLogisticsViewModel {

    private func fetchAcademies(query: String) async {
        do {
            academyResults = try await ApiService.shared.requestGetHeader(
                type: [ScheduleLogisticsDataModel.Academy].self,
                model: ScheduleLogisticsDataModel.AcademyTypeAheadRequest(query: query)
            )
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: false)
        }
    }

    private func fetchTrainingPlaces(query: String) async {
        do {
            trainingPlaceResults = try await ApiService.shared.requestGetHeader(
                type: [ScheduleLogisticsDataModel.TrainingPlace].self,
                model: ScheduleLogisticsDataModel.TrainingPlaceTypeAheadRequest(query: query)
            )
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: false)
        }
    }

    /// Server-side trainer typeahead. `userId` carries the typed keyword and `userType` the
    /// selected Trainer Type; both are encrypted in-package before sending.
    private func searchTrainers(query: String) async {
        let payload = ScheduleLogisticsDataModel.SearchTrainerRequest.Payload(
            userId: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: query),
            userType: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: trainerType.apiValue)
        )
        do {
            trainerResults = try await ApiService.shared.requestPostHeader(
                type: [ScheduleLogisticsDataModel.Trainer].self,
                model: ScheduleLogisticsDataModel.SearchTrainerRequest(),
                payload: payload
            )
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: true)
        }
    }

    /// Coordinator type-ahead (edit mode). Same encrypted contract as `searchTrainers`;
    /// coordinators are always searched as Internal users.
    private func searchCoordinators(query: String) async {
        let payload = ScheduleLogisticsDataModel.SearchActiveInActiveUserRequest.Payload(
            userId: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: query),
            userType: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: TrainerType.internal.apiValue)
        )
        do {
            coordinatorResults = try await ApiService.shared.requestPostHeader(
                type: [ScheduleLogisticsDataModel.CoordinatorUser].self,
                model: ScheduleLogisticsDataModel.SearchActiveInActiveUserRequest(),
                payload: payload
            )
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: false)
        }
    }

    private func fetchTrainingPlaceDetail(id: Int) async {
        do {
            let detail = try await ApiService.shared.requestGetHeader(
                type: ScheduleLogisticsDataModel.TrainingPlace.self,
                model: ScheduleLogisticsDataModel.TrainingPlaceDetailRequest(id: id)
            )
            coordinatorName = detail.contactPerson ?? ""
            contactNumber = detail.contactNumber ?? ""
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: false)
        }
    }

    private func fetchTags() async {
        do {
            allTags = try await ApiService.shared.requestGetHeader(
                type: [ScheduleLogisticsDataModel.Tag].self,
                model: ScheduleLogisticsDataModel.AllTagsRequest()
            )
        } catch {
            handleAPIError(error, resetLoadingState: true, showToast: false)
        }
    }
}
