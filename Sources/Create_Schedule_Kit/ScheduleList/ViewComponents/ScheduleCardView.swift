//
//  ScheduleCardView.swift
//  Create_Schedule_Kit
//
//  One schedule row on the Scheduler screen: course title + status pill, code chip with
//  quiz / edit / cancel actions, module / date-time / place / city rows, and
//  View-details / Attendance buttons.
//

import SwiftUI
import SwiftUIUtilities

struct ScheduleCardView: View {

    let schedule: ScheduleListDataModel.Schedule
    let onViewDetails: () -> Void
    let onAttendance: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void
    /// Roles that cannot own a schedule (an external trainer) lose these two icons entirely.
    var canEdit: Bool = true
    var canCancel: Bool = true
    /// Pre/Post quiz authoring. Nil hides the action (same roles as edit).
    var onQuiz: (() -> Void)? = nil

    /// A cancelled schedule is read-only — only "View details" survives.
    private var isCancelled: Bool { schedule.isCancelled }

    private var statusTint: Color { isCancelled ? CSTheme.primaryColor : .green }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleRow
            codeRow
            infoRows
            actions
                .padding(.top, 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(schedule.detailTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !schedule.statusBadgeText.isEmpty {
                statusBadge
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusTint)
                .frame(width: 6, height: 6)
            Text(schedule.statusBadgeText)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(statusTint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(statusTint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(statusTint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status \(schedule.statusBadgeText.lowercased())")
    }

    /// Code chip on the left, quiz / edit / cancel on the right. Editing, cancelling or
    /// authoring a quiz on a cancelled schedule is meaningless, and a role without the right
    /// can't do it — those go away entirely rather than sitting there disabled.
    private var codeRow: some View {
        HStack(spacing: 14) {
            if let code = schedule.scheduleCode, !code.isEmpty {
                codeChip(code)
            }
            Spacer(minLength: 8)
            if !isCancelled {
                if let onQuiz { quizButton(action: onQuiz) }
                if canEdit {
                    iconButton(systemImage: "pencil", label: "Edit schedule", action: onEdit)
                }
                if canCancel {
                    iconButton(systemImage: "xmark.circle", label: "Cancel schedule", action: onCancel)
                }
            }
        }
    }

    private func codeChip(_ code: String) -> some View {
        Text(code)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(CSTheme.primaryColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(CSTheme.primaryColor.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(CSTheme.primaryColor.opacity(0.35), lineWidth: 1)
            )
            .accessibilityLabel("Schedule code \(code)")
    }

    private func quizButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image("Quiz_Black", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .accessibilityHidden(true)
                Text("Quiz")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .accessibilityHidden(true)
            }
            .foregroundColor(CSTheme.primaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(CSTheme.primaryColor, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Bare tinted icon (edit / cancel). frame keeps the tap target at 32pt
    private func iconButton(systemImage: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(CSTheme.primaryColor)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Info

    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            // title already falls back to module name, dont print it twice
            if let module = schedule.moduleName, !module.isEmpty, module != schedule.detailTitle {
                infoRow(systemImage: "book.closed", text: module)
            }
            if !schedule.cardDateTimeText.isEmpty {
                infoRow(systemImage: "calendar", text: schedule.cardDateTimeText)
            }
            if let place = schedule.placeName, !place.isEmpty {
                infoRow(systemImage: "building.2", text: place)
            }
            if let city = schedule.city, !city.isEmpty {
                infoRow(systemImage: "building.columns", text: city)
            }
        }
    }

    private func infoRow(systemImage: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary.opacity(0.85))
        }
    }

    // MARK: - Actions

    /// A cancelled schedule keeps only "View details": attendance can no longer be taken on it.
    private var actions: some View {
        HStack(spacing: 12) {
            Button(action: onViewDetails) {
                actionLabel(title: "View details", systemImage: "eye")
                    .foregroundColor(.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if !isCancelled {
                Button(action: onAttendance) {
                    actionLabel(title: "Attendance", systemImage: "checkmark.square")
                        .foregroundColor(CSTheme.primaryColor.getDynamicTextColor)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(CSTheme.primaryColor)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
    }
}

#Preview {
    func sample(scheduleType: String?) -> ScheduleListDataModel.Schedule {
        .init(
            id: 1, scheduleCode: "SC9814", moduleName: "8953_check_vilt_01",
            courseName: "Test course 999", startDate: "2026-10-30T00:00:00", endDate: "2026-10-30T00:00:00",
            startTime: "20:00:00", endTime: "21:30:00", city: "satara", placeName: "satara",
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
                schedule: sample(scheduleType: "Scheduled"),
                onViewDetails: {}, onAttendance: {}, onEdit: {}, onCancel: {},
                onQuiz: {}
            )
            // Cancelled: no quiz, pencil, cancel or Attendance.
            ScheduleCardView(
                schedule: sample(scheduleType: "Cancelled"),
                onViewDetails: {}, onAttendance: {}, onEdit: {}, onCancel: {},
                onQuiz: {}
            )
            // External trainer: View details + Attendance only.
            ScheduleCardView(
                schedule: sample(scheduleType: "Scheduled"),
                onViewDetails: {}, onAttendance: {}, onEdit: {}, onCancel: {},
                canEdit: false, canCancel: false
            )
        }
        .padding()
    }
}
