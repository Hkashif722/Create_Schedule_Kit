//
//  ScheduleDetailView.swift
//  Create_Schedule_Kit
//
//  Schedule Details screen (opened from "View details"). Shows the schedule header,
//  info + trainer cards, and a paginated nominees section with "+ Add Nominee".
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct ScheduleDetailView: View {

    @StateObject private var viewModel: ScheduleDetailViewModel
    private let router: AnyRouter

    init(router: AnyRouter, navModel: NavigationViewModel.ScheduleDetailNavModel) {
        self.router = router
        _viewModel = StateObject(
            wrappedValue: ScheduleDetailViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScheduleDetailHeaderCard(schedule: viewModel.schedule, deliveryText: viewModel.deliveryText)

                    section("SCHEDULE INFO") {
                        ScheduleInfoCardView(rows: infoRows)
                    }

                    if viewModel.schedule.trainerName != "-" {
                        section("TRAINER") {
                            TrainerCardView(
                                name: viewModel.schedule.trainerName,
                                trainerType: viewModel.schedule.trainerType ?? "Internal"
                            )
                        }
                    }

                    nomineesSection
                }
                .padding()
            }
        }
        .background(Color.scheduleBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - Sub-views
private extension ScheduleDetailView {

    var header: some View {
        ZStack {
            Text("Schedule Details")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
            HStack {
                Button { viewModel.didTapBack() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
            content()
        }
    }

    var infoRows: [ScheduleInfoRow] {
        let s = viewModel.schedule
        return [
            ScheduleInfoRow(label: "Code", value: s.scheduleCode ?? "-"),
            ScheduleInfoRow(label: "Module", value: s.moduleName ?? "-"),
            ScheduleInfoRow(label: "Reg. end", value: s.regEndText.isEmpty ? "-" : s.regEndText),
            ScheduleInfoRow(label: "Coordinator", value: viewModel.coordinatorText),
            ScheduleInfoRow(label: "Seat capacity", value: viewModel.seatCapacityText)
        ]
    }

    var nomineesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NOMINEES (\(viewModel.nomineesCountText))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.canNominate {
                    Button { viewModel.didTapAddNominee() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                            Text("Add Nominee").font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(ColorUtility.primaryColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.loadingState.isLoading && viewModel.items.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if viewModel.items.isEmpty {
                Text("No nominees yet")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(viewModel.items) { nominee in
                    NomineeRowView(
                        nominee: nominee,
                        onDelete: { viewModel.didTapDeleteNominee(nominee) },
                        canDelete: viewModel.canDeleteNominees
                    )
                        .onAppear { viewModel.loadMoreIfNeeded(currentItem: nominee) }
                }
                if viewModel.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
        }
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
    let schedule = ScheduleListDataModel.Schedule(
        id: 1, scheduleCode: "SC6572", moduleName: "test parichay", courseName: "classroom1",
        startDate: "2026-06-24T00:00:00", endDate: "2026-06-24T00:00:00",
        startTime: "18:07:00", endTime: "18:07:00", city: "Bangalore", placeName: "Bangalore University",
        academyAgencyName: nil, participantsCount: nil, moduleId: 42175, courseID: 56285, courseCode: nil,
        registrationEndDate: "2026-06-24T00:00:00", seatCapacity: "20", scheduleCapacity: 20,
        contactPersonName: "Sachin Shimpi", trainerType: "Internal", academyTrainerName: "Kashif User",
        trainerDescription: nil, scheduleType: "Planned Training", purpose: "Planned Training",
        timezone: nil, isWebinar: false, webinarType: nil
    )
    return ScheduleDetailView(router: router, navModel: .init(schedule: schedule))
}
