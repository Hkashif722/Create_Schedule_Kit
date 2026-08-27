//
//  ScheduleDetailHeaderCard.swift
//  Create_Schedule_Kit
//
//  Top card of the Schedule Details screen: icon, title, status pill and the
//  date/location/mode summary rows.
//

import SwiftUI
import SwiftUIUtilities

struct ScheduleDetailHeaderCard: View {

    let schedule: ScheduleListDataModel.Schedule
    let deliveryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ColorUtility.primaryColor)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(ColorUtility.primaryColor.getDynamicTextColor)
                    )
                VStack(alignment: .leading, spacing: 8) {
                    Text(schedule.detailTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    statusPill
                }
                Spacer(minLength: 0)
            }

            Divider().padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 12) {
                if !schedule.dateText.isEmpty {
                    row(icon: "calendar") {
                        HStack(spacing: 8) {
                            Text(schedule.dateText).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                            if !schedule.timeRangeText.isEmpty {
                                Text(schedule.timeRangeText).font(.system(size: 16)).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                if let city = schedule.city, !city.isEmpty {
                    row(icon: "mappin.and.ellipse") { text(city) }
                }
                if let place = schedule.placeName, !place.isEmpty {
                    row(icon: "building.2") { text(place) }
                }
                row(icon: "wifi") { text(deliveryText, secondary: true) }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(ColorUtility.primaryColor).frame(width: 7, height: 7)
            Text(schedule.statusText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ColorUtility.primaryColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(ColorUtility.primaryColor.opacity(0.12)))
    }

    private func row<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ColorUtility.primaryColor)
                .frame(width: 22)
            content()
            Spacer(minLength: 0)
        }
    }

    private func text(_ value: String, secondary: Bool = false) -> some View {
        Text(value)
            .font(.system(size: 16, weight: secondary ? .regular : .semibold))
            .foregroundColor(secondary ? .secondary : .primary)
    }
}

#Preview {
    ScheduleDetailHeaderCard(
        schedule: .init(
            id: 1, scheduleCode: "SC6572", moduleName: "test parichay", courseName: "classroom1",
            startDate: "2026-06-24T00:00:00", endDate: "2026-06-24T00:00:00",
            startTime: "18:07:00", endTime: "18:07:00", city: "Bangalore", placeName: "Bangalore University",
            academyAgencyName: nil, participantsCount: nil, moduleId: 42175, courseID: 56285, courseCode: nil,
            registrationEndDate: "2026-06-24T00:00:00", seatCapacity: "20", scheduleCapacity: 20,
            contactPersonName: "Sachin Shimpi", trainerType: "Internal", academyTrainerName: "Kashif User",
            trainerDescription: nil, scheduleType: "Planned Training", purpose: "Planned Training",
            timezone: nil, isWebinar: false, webinarType: nil
        ),
        deliveryText: "Offline · Bangalore"
    )
    .padding()
}
