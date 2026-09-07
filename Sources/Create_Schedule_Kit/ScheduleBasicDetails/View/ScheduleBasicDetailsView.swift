//
//  ScheduleBasicDetailsView.swift
//  Create_Schedule_Kit
//
//  Step 1 — Basic Details. Pure layout; all logic lives in the view model.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct ScheduleBasicDetailsView: View {

    @StateObject private var viewModel: ScheduleBasicDetailsViewModel
    private let router: AnyRouter

    init(router: AnyRouter, draft: ScheduleDraft, isEditMode: Bool = false, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: ScheduleBasicDetailsViewModel(
                router: router, draft: draft, isEditMode: isEditMode, onBack: onBack, onContinue: onContinue
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    basicInfoCard.zIndex(3)
                    datesCard.zIndex(2)
                    holidaysCard.zIndex(1)
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
private extension ScheduleBasicDetailsView {

    var basicInfoCard: some View {
        CSSectionCard(
            icon: "doc.text",
            iconColor: ColorUtility.primaryColor,
            title: "Basic information",
            subtitle: "Schedule identity & course"
        ) {
            // Strictly-decreasing zIndex top→bottom so each row's downward-expanding
            // dropdown list draws above every row beneath it.
            VStack(alignment: .leading, spacing: 18) {
                scheduleCodeField.zIndex(8)
                courseField.zIndex(7)
                moduleField.zIndex(6)
                if viewModel.isEditMode { categoryFields.zIndex(5) }
                deliveryField.zIndex(4)
                if viewModel.showWebinarSection { webinarField.zIndex(3) }
                if viewModel.showCredentialSection { credentialCard.zIndex(2) }
                timezoneField.zIndex(1)
            }
        }
    }

    var datesCard: some View {
        CSSectionCard(
            icon: "calendar",
            iconColor: .green,
            title: "Dates & times",
            subtitle: "When the schedule runs"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                dateRow
                timeRow
                registrationField
                if viewModel.showTeamsLinkField { teamsLinkField }
            }
        }
    }
}

// MARK: - Fields
private extension ScheduleBasicDetailsView {

    @ViewBuilder
    var scheduleCodeField: some View {
        if viewModel.isScheduleCodeEditable {
            CSTextField(
                title: "Schedule code",
                isRequired: true,
                placeholder: "Enter schedule code",
                text: $viewModel.scheduleCode
            )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                CSFieldLabel(title: "Schedule code")
                HStack {
                    Text(viewModel.scheduleCode.isEmpty ? "—" : viewModel.scheduleCode)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "lock.fill").foregroundColor(.secondary).font(.caption)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    var courseField: some View {
        if viewModel.isEditMode {
            CSReadOnlyField(title: "Course name", value: viewModel.selectedCourse?.title ?? "", isRequired: true)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                CSFieldLabel(title: "Course name", isRequired: true)
                DropDownMenuListViewPkg(
                    viewModel.courseResults,
                    placeholder: "Search a course",
                    selectedOption: viewModel.selectedCourse,
                    isSearchable: true,
                    onSearchTextChange: { viewModel.onCourseSearch($0) },
                    onSelection: { viewModel.didSelectCourse($0) }
                )
            }
        }
    }

    @ViewBuilder
    var moduleField: some View {
        if viewModel.isEditMode {
            CSReadOnlyField(title: "Module name", value: viewModel.selectedModule?.title ?? "", isRequired: true)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                CSFieldLabel(title: "Module name", isRequired: true)
                DropDownMenuListViewPkg(
                    viewModel.modules,
                    placeholder: viewModel.selectedCourse == nil ? "Select a course first" : "Select module",
                    selectedOption: viewModel.selectedModule,
                    isSearchable: false,
                    onSelection: { viewModel.didSelectModule($0) }
                )
            }
        }
    }

    /// Read-only category rows (edit mode only), resolved from the locked module.
    var categoryFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            CSReadOnlyField(title: "Category", value: viewModel.categoryText)
            HStack(alignment: .top, spacing: 12) {
                CSReadOnlyField(title: "Sub category", value: viewModel.subCategoryText)
                CSReadOnlyField(title: "Sub sub category", value: viewModel.subSubCategoryText)
            }
        }
    }

    var deliveryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Delivery mode", isRequired: true)
            CSSegmentedControl(
                options: viewModel.deliveryOptions,
                title: { $0.displayTitle },
                icon: { $0 == .online ? "wifi" : "building.2" },
                isEnabled: !viewModel.isEditMode,
                selection: Binding(
                    get: { viewModel.deliveryMode },
                    set: { viewModel.didSelectDelivery($0) }
                )
            )
        }
    }

    @ViewBuilder
    var webinarField: some View {
        if viewModel.isEditMode {
            CSReadOnlyField(title: "Webinar type", value: viewModel.webinarType?.displayTitle ?? "", isRequired: true)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                CSFieldLabel(title: "Webinar type", isRequired: true)
                DropDownMenuListViewPkg(
                    webinarMenuItems,
                    placeholder: "Select webinar type",
                    selectedOption: selectedWebinarMenuItem,
                    isSearchable: false,
                    onSelection: { item in
                        let type = viewModel.webinarOptions[item.id]
                        viewModel.didSelectWebinarType(type)
                    }
                )
            }
        }
    }

    var credentialCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !viewModel.isEditMode, let credentials = viewModel.credentials {
                CSFieldLabel(title: "Webinar account", isRequired: true)
                DropDownMenuListViewPkg(
                    credentials,
                    placeholder: "Select webinar account",
                    selectedOption: viewModel.selectedCredential,
                    isSearchable: false,
                    onSelection: { viewModel.didSelectCredential($0) }
                )
                .zIndex(2)
            }

            CredentialRevealCard(
                providerTitle: viewModel.webinarType?.displayTitle ?? "",
                displayValue: viewModel.credentialDisplayValue,
                username: viewModel.selectedCredential?.username,
                isRevealed: viewModel.isCredentialRevealed,
                onToggleReveal: { viewModel.toggleCredentialReveal() }
            )
            .zIndex(1)
        }
    }

    var teamsLinkField: some View {
        TeamsStaticLinkField(
            title: "Teams Link",
            text: viewModel.teamsLink,
            errorMessage: viewModel.teamsLinkError,
            onTextChanged: { viewModel.didEditTeamsLink($0) }
        )
        // The field keeps its own state and only reads `text` on first appear, so it is
        // rebuilt whenever the model clears the link.
        .id("teams-link-\(viewModel.linkFieldToken)")
    }

    /// The dropdown is withheld until the timezone list has loaded.
    /// `DropDownMenuListViewPkg` force-opens its menu whenever a *searchable* option set
    /// goes from empty to non-empty — that hook is what makes course/trainer search
    /// results pop open as they arrive. The timezone list is not typed into; it is
    /// fetched once in `loadData()`, so mounting the control while empty tripped that
    /// same hook and sprang the menu open with no user interaction. Mounting only once
    /// the options exist means the control never observes the transition. It also keeps
    /// the edit-mode preselection, since the control snapshots `selectedOption` into
    /// `@State` at init and would otherwise capture a nil timezone.
    @ViewBuilder
    var timezoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Time zone")
            if viewModel.timezones.isEmpty {
                timezonePlaceholder
            } else {
                DropDownMenuListViewPkg(
                    viewModel.timezones,
                    placeholder: "Select time zone",
                    selectedOption: viewModel.selectedTimezone,
                    isSearchable: true,
                    onSelection: { viewModel.didSelectTimezone($0) }
                )
            }
        }
    }

    /// Inert stand-in matching the dropdown's footprint so the form does not reflow
    /// when the real control takes its place.
    var timezonePlaceholder: some View {
        HStack {
            Text("Loading time zones\u{2026}")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 45)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    var dateRow: some View {
        HStack(alignment: .top, spacing: 12) {
            DatePickerTextFieldPkg(
                router: router,
                title: "Start date",
                placeHolder: "Select start date",
                disabledWeekdays: ScheduleDateRules.nonWorkingWeekdays,
                initialDateString: viewModel.startDateString,
                onDateSelected: { viewModel.didSelectStartDate($0) }
            )
            .id("start-\(viewModel.dateFieldToken)")
            DatePickerTextFieldPkg(
                router: router,
                title: "End date",
                placeHolder: "Select end date",
                minimumDate: viewModel.endDateMinimum,
                disabledWeekdays: ScheduleDateRules.nonWorkingWeekdays,
                isEnabled: viewModel.endAndRegEnabled,
                initialDateString: viewModel.endDateString,
                onDateSelected: { viewModel.didSelectEndDate($0) }
            )
            .id("end-\(viewModel.startDateString ?? "")-\(viewModel.dateFieldToken)")
        }
    }

    var timeRow: some View {
        HStack(alignment: .top, spacing: 12) {
            TimePickerTextField(
                router: router,
                title: "Start time",
                timeFormat: ScheduleDateRules.timeFormat,
                initialTimeString: viewModel.startTime,
                onTimeSelected: { viewModel.didSelectStartTime($0) }
            )
            TimePickerTextField(
                router: router,
                title: "End time",
                timeFormat: ScheduleDateRules.timeFormat,
                initialTimeString: viewModel.endTime,
                onTimeSelected: { viewModel.didSelectEndTime($0) }
            )
            // The picker commits the tapped time to its own state before handing it over,
            // so a refused end time would stay on screen. Keying on the view model's token
            // rebuilds the field from the model whenever a selection is rejected or
            // cleared. Same remount trick as the end-date field above.
            .id("end-time-\(viewModel.endTimeFieldToken)")
        }
    }

    var registrationField: some View {
        DatePickerTextFieldPkg(
            router: router,
            title: "Registration end date",
            placeHolder: "Select registration end date",
            minimumDate: viewModel.registrationMinimum,
            maximumDate: viewModel.registrationMaximum,
            disabledWeekdays: ScheduleDateRules.nonWorkingWeekdays,
            isEnabled: viewModel.endAndRegEnabled,
            initialDateString: viewModel.registrationEndDateString,
            onDateSelected: { viewModel.didSelectRegistrationEndDate($0) }
        )
        .id("reg-\(viewModel.startDateString ?? "")-\(viewModel.dateFieldToken)")
    }

    var holidaysCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "sun.max")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Set holidays")
                    .font(.system(size: 17, weight: .bold))
                Text(viewModel.holidaysSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { viewModel.holidaysEnabled },
                set: { viewModel.toggleHolidays($0) }
            ))
            .labelsHidden()
            .tint(ColorUtility.primaryColor)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .contentShape(Rectangle())
        .opacity(viewModel.canSetHolidays ? 1 : 0.55)
        .onTapGesture {
            guard viewModel.canSetHolidays else { return }
            viewModel.openHolidaysSheet()
        }
        .disabled(!viewModel.canSetHolidays)
    }

    var footer: some View {
        CSNavFooter(
            showBack: false,
            isNextEnabled: viewModel.canContinue,
            onNext: { viewModel.didTapContinue() }
        )
    }

    // MARK: Webinar dropdown mapping
    var webinarMenuItems: [DropDownMenuModelPkg] {
        viewModel.webinarOptions.enumerated().map {
            DropDownMenuModelPkg(id: $0.offset, title: $0.element.displayTitle)
        }
    }

    var selectedWebinarMenuItem: DropDownMenuModelPkg? {
        guard let type = viewModel.webinarType,
              let index = viewModel.webinarOptions.firstIndex(of: type) else { return nil }
        return DropDownMenuModelPkg(id: index, title: type.displayTitle)
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
    return ScheduleBasicDetailsView(router: router, draft: ScheduleDraft(), onBack: {}, onContinue: {})
}
