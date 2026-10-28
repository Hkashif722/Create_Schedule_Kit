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
    /// True when the Feedback step is switched off org-wide and this step submits the
    /// schedule instead of advancing — only the primary button's wording changes here.
    private let isFinalStep: Bool

    init(router: AnyRouter, draft: ScheduleDraft, isEditMode: Bool = false, isFinalStep: Bool = false, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.router = router
        self.isFinalStep = isFinalStep
        _viewModel = StateObject(
            wrappedValue: ScheduleLogisticsViewModel(
                router: router, draft: draft, isEditMode: isEditMode, onBack: onBack, onContinue: onContinue
            )
        )
    }

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
                placeTypeField.zIndex(3)
                venueOwnerField.zIndex(2)
                trainingPlaceField.zIndex(1)
            }
        }
    }

    var trainerCard: some View {
        CSSectionCard(
            icon: "person",
            iconColor: CSTheme.primaryColor,
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
                tagsField.zIndex(1)
                coordinatorField.zIndex(2)
                contactField.zIndex(1)
            }
        }
    }

    var addAnotherTrainerButton: some View {
        Button {
            viewModel.didTapAddAnotherTrainer()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("Add another trainer")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(CSTheme.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fields
private extension ScheduleLogisticsView {

    var placeTypeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Training place type")
            CSSegmentedControl(
                options: viewModel.placeTypeOptions,
                title: { $0.displayTitle },
                selection: Binding(
                    get: { viewModel.placeType },
                    set: { viewModel.didSelectPlaceType($0) }
                )
            )
        }
    }

    /// Internal venues belong to an academy from the directory; external ones to an agency
    /// with no directory to search, so that name is typed in.
    @ViewBuilder
    var venueOwnerField: some View {
        switch viewModel.placeType {
        case .internal: academyField
        case .external: agencyField
        }
    }

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

    var agencyField: some View {
        CSTextField(
            title: "Agency name",
            isRequired: true,
            placeholder: "Enter agency name",
            text: $viewModel.agencyName
        )
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

    @ViewBuilder
    var trainerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Trainer name", isRequired: true)
            if viewModel.showsTrainerSourceMenu {
                TrainerSourceMenuField(
                    placeholder: "Trainer Name",
                    isMenuOpen: $viewModel.isTrainerSourceMenuOpen,
                    onSelect: { viewModel.didSelectTrainerSource($0) }
                )
            } else {
                DropDownMenuListViewPkg(
                    viewModel.trainerResults,
                    placeholder: "Search and add trainer",
                    isSearchable: true,
                    focusRequest: viewModel.trainerFocusToken,
                    onSearchTextChange: { viewModel.onTrainerSearch($0) },
                    onSelection: { viewModel.didSelectTrainer($0) }
                )
                // The control keeps the picked name in its own state, so a trainer chosen
                // under the previous Trainer type stayed on screen after the switch.
                // Keying it on the type rebuilds the field empty. Same remount trick as
                // the date and time fields on step 1.
                .id("trainer-\(viewModel.trainerType.rawValue)")
            }
        }
    }

    var selectedTrainersGrid: some View {
        CSChipFlow(viewModel.selectedTrainers) { trainer in
            CSRemovableChip(title: trainer.displayNameWithType) {
                viewModel.removeTrainer(trainer)
            }
        }
    }

    var tagsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            CSFieldLabel(title: "Select tags")
            CSChipFlow(viewModel.allTags) { tag in
                CSSelectableChip(
                    title: tag.description,
                    isSelected: viewModel.isTagSelected(tag),
                    onTap: { viewModel.toggleTag(tag) }
                )
            }
        }
    }

    /// Read-only in both modes: the coordinator is the training place's contact person,
    /// so it is auto-filled from the place — never typed, and never searched in edit mode.
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
            placeholder: viewModel.isEditMode ? "Enter contact number" : "Auto-filled from training place",
            text: $viewModel.contactNumber,
            isReadOnly: !viewModel.isEditMode,
            keyboardType: .phonePad,
            leadingSystemImage: "phone"
        )
    }

    var footer: some View {
        CSNavFooter(
            nextTitle: isFinalStep ? (viewModel.isEditMode ? "Update Schedule" : "Create Schedule") : "Next",
            nextSystemImage: isFinalStep ? nil : "arrow.right",
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
