//
//  ScheduleCardView.swift
//  Create_Schedule_Kit
//
//  One schedule row on the Scheduler screen: title + edit, date/time, location,
//  participants badge, and View-details / Attendance actions.
//

import SwiftUI
import SwiftUIUtilities

struct ScheduleCardView: View {

    let schedule: ScheduleListDataModel.Schedule
    let participants: Int
    let onViewDetails: () -> Void
    let onAttendance: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void

    private var hasParticipants: Bool { participants > 0 }

    /// A cancelled schedule is read-only — only "View details" survives.
    private var isCancelled: Bool { schedule.isCancelled }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            titleRow
            infoRows
            Divider()
            badges
            actions
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Rows

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(schedule.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Spacer(minLength: 8)
            // Editing or cancelling an already-cancelled schedule is meaningless, so both icons
            // go away entirely rather than sitting there disabled.
            if !isCancelled {
                iconButton(systemImage: "pencil", action: onEdit)
                iconButton(systemImage: "nosign", action: onCancel)
            }
        }
    }

    /// Square tinted icon action in the title row (edit / cancel).
    private func iconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ColorUtility.primaryColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ColorUtility.primaryColor.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(ColorUtility.primaryColor)
                Text(schedule.dateText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                if !schedule.timeRangeText.isEmpty {
                    Text(schedule.timeRangeText)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            if !schedule.locationText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor(ColorUtility.primaryColor)
                    Text(schedule.locationText)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var badges: some View {
        HStack(spacing: 8) {
            participantsBadge
            if isCancelled { cancelledBadge }
            Spacer(minLength: 0)
        }
    }

    private var participantsBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2")
                .font(.system(size: 13, weight: .semibold))
            Text("\(participants) Participants")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(hasParticipants ? .green : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill((hasParticipants ? Color.green : Color.gray).opacity(0.15)))
    }

    /// Explains why the card's actions are gone — without it a cancelled row just looks broken.
    private var cancelledBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Cancelled")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(ColorUtility.primaryColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(ColorUtility.primaryColor.opacity(0.12)))
    }

    /// A cancelled schedule keeps only "View details": attendance can no longer be taken on it.
    private var actions: some View {
        HStack(spacing: 12) {
            actionButton(title: "View details", systemImage: "eye",
                         tint: .primary, isEnabled: true, action: onViewDetails)
            if !isCancelled {
                actionButton(title: "Attendance", systemImage: "checklist",
                             tint: ColorUtility.primaryColor, isEnabled: true, action: onAttendance)
            }
        }
    }

    private func actionButton(title: String, systemImage: String, tint: Color,
                              isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 14, weight: .semibold))
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundColor(isEnabled ? tint : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isEnabled ? Color(.systemGray3) : Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    func sample(scheduleType: String?) -> ScheduleListDataModel.Schedule {
        .init(
            id: 1, scheduleCode: "SC6641", moduleName: "5544_Self nomination capacity",
            courseName: "absent flow", startDate: "2026-06-27T00:00:00", endDate: "2026-06-27T00:00:00",
            startTime: "13:30:00", endTime: "18:30:00", city: "Pune", placeName: "punea",
            academyAgencyName: "Enthralltech", participantsCount: 0,
            moduleId: nil, courseID: nil, courseCode: nil, registrationEndDate: nil,
            seatCapacity: nil, scheduleCapacity: nil, contactPersonName: nil, trainerType: nil,
            academyTrainerName: nil, trainerDescription: nil, scheduleType: scheduleType, purpose: nil,
            timezone: nil, isWebinar: nil, webinarType: nil
        )
    }

    return ScrollView {
        VStack(spacing: 16) {
            ScheduleCardView(
                schedule: sample(scheduleType: "Scheduled"), participants: 3,
                onViewDetails: {}, onAttendance: {}, onEdit: {}, onCancel: {}
            )
            // Cancelled: no pencil, no Attendance, no Cancel Schedule.
            ScheduleCardView(
                schedule: sample(scheduleType: "Cancelled"), participants: 3,
                onViewDetails: {}, onAttendance: {}, onEdit: {}, onCancel: {}
            )
        }
        .padding()
    }
}
