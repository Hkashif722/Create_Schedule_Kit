//
//  QuizPackagePickerRow.swift
//  Create_Schedule_Kit
//

import SwiftUI

struct QuizPackagePickerRow: View {

    let package: ScheduleQuizDataModel.PackageListItem
    let isSelected: Bool
    let isAttached: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                QuizCheckbox(isOn: isSelected, isEnabled: !isAttached)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(package.packageName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        if isAttached {
                            CSStatusChip(title: "Already on this quiz", tint: .secondary)
                        }
                    }
                    if let description = package.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Text("\(package.questionCount.questionsLabel) · \(package.totalMarks.marksLabel)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    if package.unavailableQuestionCount > 0 {
                        Label(unavailableText, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12.5))
                            .foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected && !isAttached ? CSTheme.primaryColor.opacity(0.06) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected && !isAttached ? CSTheme.primaryColor : Color(.systemGray4), lineWidth: 1)
            )
            .opacity(isAttached ? 0.6 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAttached)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var unavailableText: String {
        let count = package.unavailableQuestionCount
        return count == 1
            ? "1 question no longer in the question bank (skipped on save)"
            : "\(count) questions no longer in the question bank (skipped on save)"
    }
}

/// Square tick used by both quiz pickers.
struct QuizCheckbox: View {
    let isOn: Bool
    var isEnabled: Bool = true

    var body: some View {
        Image(systemName: isOn ? "checkmark.square.fill" : "square")
            .font(.system(size: 22))
            .foregroundColor(isOn ? (isEnabled ? CSTheme.primaryColor : Color(.systemGray3)) : Color(.systemGray3))
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 10) {
        QuizPackagePickerRow(
            package: .init(id: 1, packageName: "Fire basics", description: "Core fire awareness questions",
                           questionCount: 5, unavailableQuestionCount: 1, totalMarks: 10),
            isSelected: true, isAttached: false, onTap: {}
        )
        QuizPackagePickerRow(
            package: .init(id: 2, packageName: "Package1", description: "Created from Postman",
                           questionCount: 2, unavailableQuestionCount: 0, totalMarks: 2),
            isSelected: true, isAttached: true, onTap: {}
        )
    }
    .padding()
}
