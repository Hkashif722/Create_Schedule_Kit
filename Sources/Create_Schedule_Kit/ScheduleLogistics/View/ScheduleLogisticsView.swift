//
//  ScheduleLogisticsView.swift
//  Create_Schedule_Kit
//
//  Step 2 — Logistics. Pure layout; all logic lives in the view model.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct ScheduleLogisticsView: View {

    @StateObject private var viewModel: ScheduleLogisticsViewModel
    private let router: AnyRouter

    init(router: AnyRouter, draft: ScheduleDraft, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: ScheduleLogisticsViewModel(
                router: router, draft: draft, onBack: onBack, onContinue: onContinue
            )
        )
    }

    private let chipColumns = [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .leading)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    venueCard.zIndex(3)
                    trainerCard.zIndex(2)
                    tagsCard.zIndex(1)
                }
                .padding()
            }
            footer
        }
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.loadData() }
    }
}

// MARK: - Cards
private extension ScheduleLogisticsView {

    var venueCard: some View {
        CSSectionCard(
            icon: "mappin",
            iconColor: .red,
            title: "Venue",
            subtitle: "Where it takes place"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                academyField.zIndex(2)
                trainingPlaceField.zIndex(1)
            }
        }
    }

    var trainerCard: some View {
        CSSectionCard(
            icon: "person",
            iconColor: ColorUtility.primaryColor,
            title: "Trainer",
            subtitle: "Who delivers the session"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                trainerTypeField.zIndex(4)
                trainerField.zIndex(3)
                if !viewModel.selectedTrainers.isEmpty { selectedTrainersGrid.zIndex(2) }
                addAnotherTrainerButton.zIndex(1)
            }
        }
    }

    var tagsCard: some View {
        CSSectionCard(
            icon: "tag",
            iconColor: .blue,
            title: "Tags & coordination",
            subtitle: "Labels & point of contact"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                tagsField
                coordinatorField
                contactField
            }
        }
    }

    var addAnotherTrainerButton: some View {
        Button {
            // The trainer search above supports adding multiple trainers; this is the
            // affordance shown in the design to prompt adding another.
            // TODO: focus/reset the trainer search field when field-focus is wired.
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("Add another trainer")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(ColorUtility.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fields
private extension ScheduleLogisticsView {

    var academyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Academy name", isRequired: true)
            DropDownMenuListViewPkg(
                viewModel.academyResults,
                placeholder: "Type to search academies…",
                selectedOption: viewModel.selectedAcademy,
                isSearchable: true,
                onSearchTextChange: { viewModel.onAcademySearch($0) },
                onSelection: { viewModel.didSelectAcademy($0) }
            )
        }
    }

    var trainingPlaceField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Training place name")
            DropDownMenuListViewPkg(
                viewModel.trainingPlaceResults,
                placeholder: "Type to search venues…",
                selectedOption: viewModel.selectedTrainingPlace,
                isSearchable: true,
                onSearchTextChange: { viewModel.onTrainingPlaceSearch($0) },
                onSelection: { viewModel.didSelectTrainingPlace($0) }
            )
        }
    }

    var trainerTypeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Trainer type")
            CSSegmentedControl(
                options: viewModel.trainerTypeOptions,
                title: { $0.displayTitle },
                selection: Binding(
                    get: { viewModel.trainerType },
                    set: { viewModel.didSelectTrainerType($0) }
                )
            )
        }
    }

    var trainerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Trainer name", isRequired: true)
            DropDownMenuListViewPkg(
                viewModel.trainerResults,
                placeholder: "Search and add trainer",
                isSearchable: true,
                onSearchTextChange: { viewModel.onTrainerSearch($0) },
                onSelection: { viewModel.didSelectTrainer($0) }
            )
        }
    }

    var selectedTrainersGrid: some View {
        LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
            ForEach(viewModel.selectedTrainers) { trainer in
                CSRemovableChip(title: trainer.displayName) {
                    viewModel.removeTrainer(trainer)
                }
            }
        }
    }

    var tagsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            CSFieldLabel(title: "Select tags")
            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                ForEach(viewModel.allTags) { tag in
                    CSSelectableChip(
                        title: tag.description,
                        isSelected: viewModel.isTagSelected(tag),
                        onTap: { viewModel.toggleTag(tag) }
                    )
                }
            }
        }
    }

    var coordinatorField: some View {
        CSTextField(
            title: "Coordinator name",
            isRequired: true,
            placeholder: "Auto-filled from training place",
            text: $viewModel.coordinatorName,
            isReadOnly: true,
            leadingSystemImage: "person"
        )
    }

    var contactField: some View {
        CSTextField(
            title: "Contact number",
            isRequired: true,
            placeholder: "Auto-filled from training place",
            text: $viewModel.contactNumber,
            isReadOnly: true,
            keyboardType: .phonePad,
            leadingSystemImage: "phone"
        )
    }

    var footer: some View {
        CSNavFooter(
            isNextEnabled: viewModel.canContinue,
            onBack: { viewModel.didTapBack() },
            onNext: { viewModel.didTapContinue() }
        )
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    SwiftUtilityEnvironment.configure(
        SwiftUtilityConfig(
            encryptionDecryptionKey: "preview-key",
            isBlobEnabled: true,
            orgCode: "preview",
            configurableDate: "dd-MM-yyyy",
            baseURL: "",
            lxpOPath: "",
            lxpBlobPath: "",
            lxpBlobPath1: ""
        )
    )
    return ScheduleLogisticsView(router: router, draft: ScheduleDraft(), onBack: {}, onContinue: {})
}
