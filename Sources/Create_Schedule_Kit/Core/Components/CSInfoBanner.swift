//
//  CSInfoBanner.swift
//  Create_Schedule_Kit
//
//  Tinted notice box: icon, bold title, body text. Used for the quiz screens' edit-constraint,
//  report and lock notices.
//

import SwiftUI

struct CSInfoBanner: View {

    enum Style {
        case danger, info, warning, success

        var tint: Color {
            switch self {
            case .danger:  return Color(red: 0.80, green: 0.13, blue: 0.15)
            case .info:    return Color(red: 0.15, green: 0.39, blue: 0.85)
            case .warning: return Color(red: 0.62, green: 0.41, blue: 0.0)
            case .success: return Color(red: 0.13, green: 0.50, blue: 0.27)
            }
        }

        var systemImage: String {
            switch self {
            case .danger:  return "exclamationmark.triangle.fill"
            case .info:    return "info.circle.fill"
            case .warning: return "lock.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }

    let style: Style
    var title: String? = nil
    let message: String
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage ?? style.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(style.tint)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(style.tint)
                }
                Text(message)
                    .font(.system(size: 13.5))
                    .foregroundColor(style.tint.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(style.tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style.tint.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 12) {
        CSInfoBanner(
            style: .danger,
            title: "Edit Constraint",
            message: "Questions can be edited only until a participant starts the assessment."
        )
        CSInfoBanner(
            style: .info,
            title: "ILT Schedule Report",
            message: "Pre & Post quiz scores and pass percentages will appear per learner in the ILT Schedule Report."
        )
        CSInfoBanner(style: .warning, message: "Learners have started this quiz.")
        CSInfoBanner(style: .success, title: "Saved · 6 questions · 43 marks", message: "Total marks changed from 3 to 4.")
    }
    .padding()
}
