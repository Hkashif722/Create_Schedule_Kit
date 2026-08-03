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

    init(router: AnyRouter, draft: ScheduleDraft, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: ScheduleBasicDetailsViewModel(
                router: router, draft: draft, onBack: onBack, onContinue: onContinue
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
                scheduleCodeField.zIndex(7)
                courseField.zIndex(6)
                moduleField.zIndex(5)
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
            }
        }
    }
}

// MARK: - Fields
private extension ScheduleBasicDetailsView {

    var scheduleCodeField: some View {
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

    var courseField: some View {
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

    var moduleField: some View {
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

    var deliveryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Delivery mode", isRequired: true)
            CSSegmentedControl(
                options: viewModel.deliveryOptions,
                title: { $0.displayTitle },
                icon: { $0 == .online ? "wifi" : "building.2" },
                selection: Binding(
                    get: { viewModel.deliveryMode },
                    set: { viewModel.didSelectDelivery($0) }
                )
            )
        }
    }

    var webinarField: some View {
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

    var credentialCard: some View {
        CredentialRevealCard(
            providerTitle: viewModel.webinarType?.displayTitle ?? "",
            displayValue: viewModel.credentialDisplayValue,
            username: viewModel.credential?.username,
            isRevealed: viewModel.isCredentialRevealed,
            onToggleReveal: { viewModel.toggleCredentialReveal() }
        )
    }

    var timezoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            CSFieldLabel(title: "Time zone")
            DropDownMenuListViewPkg(
                viewModel.timezones,
                placeholder: "Select time zone",
                selectedOption: viewModel.selectedTimezone,
                isSearchable: true,
                onSelection: { viewModel.selectedTimezone = $0 }
            )
        }
    }

    var dateRow: some View {
        HStack(alignment: .top, spacing: 12) {
            DatePickerTextFieldPkg(
                router: router,
                title: "Start date",
                placeHolder: "Select start date",
                initialDateString: viewModel.startDateString,
                onDateSelected: { viewModel.didSelectStartDate($0) }
            )
            DatePickerTextFieldPkg(
                router: router,
                title: "End date",
                placeHolder: "Select end date",
                minimumDate: viewModel.endDateMinimum,
                isEnabled: viewModel.endAndRegEnabled,
                initialDateString: viewModel.endDateString,
                onDateSelected: { viewModel.didSelectEndDate($0) }
            )
            .id("end-\(viewModel.startDateString ?? "")")
        }
    }

    var timeRow: some View {
        HStack(alignment: .top, spacing: 12) {
            TimePickerTextField(
                router: router,
                title: "Start time",
                initialTimeString: viewModel.startTime,
                onTimeSelected: { viewModel.didSelectStartTime($0) }
            )
            TimePickerTextField(
                router: router,
                title: "End time",
                initialTimeString: viewModel.endTime,
                onTimeSelected: { viewModel.didSelectEndTime($0) }
            )
        }
    }

    var registrationField: some View {
        DatePickerTextFieldPkg(
            router: router,
            title: "Registration end date",
            placeHolder: "Select registration end date",
            minimumDate: viewModel.registrationMinimum,
            maximumDate: viewModel.registrationMaximum,
            isEnabled: viewModel.endAndRegEnabled,
            initialDateString: viewModel.registrationEndDateString,
            onDateSelected: { viewModel.didSelectRegistrationEndDate($0) }
        )
        .id("reg-\(viewModel.startDateString ?? "")")
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
        .onTapGesture { viewModel.openHolidaysSheet() }
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
