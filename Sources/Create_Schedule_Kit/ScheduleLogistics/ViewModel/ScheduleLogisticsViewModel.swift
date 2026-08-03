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
    /// Last typed trainer keyword, kept so the search can re-run when Trainer Type changes.
    private var trainerQuery: String = ""

    @Published var allTags: [ScheduleLogisticsDataModel.Tag] = []
    @Published var selectedTags: [ScheduleLogisticsDataModel.Tag] = []

    @Published var coordinatorName: String = ""
    @Published var contactNumber: String = ""

    // MARK: - Init
    init(router: AnyRouter, draft: ScheduleDraft, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.draft = draft
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
    }
}

// MARK: - Derived UI State
extension ScheduleLogisticsViewModel {

    var trainerTypeOptions: [TrainerType] { TrainerType.allCases }

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
        // Results are scoped to the type, so re-search (or clear) on change.
        let query = trainerQuery
        guard query.count >= 2 else { trainerResults = []; return }
        Task { [weak self] in await self?.searchTrainers(query: query) }
    }

    func onTrainerSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        trainerQuery = trimmed
        guard trimmed.count >= 2 else { trainerResults = []; return }
        Task { [weak self] in await self?.searchTrainers(query: trimmed) }
    }

    func didSelectTrainer(_ trainer: ScheduleLogisticsDataModel.Trainer) {
        guard !selectedTrainers.contains(where: { $0.id == trainer.id }) else { return }
        selectedTrainers.append(trainer)
    }

    func removeTrainer(_ trainer: ScheduleLogisticsDataModel.Trainer) {
        selectedTrainers.removeAll { $0.id == trainer.id }
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
