//
//  CSSectionCard.swift
//  Create_Schedule_Kit
//
//  White rounded section card with a colored icon badge, title/subtitle, an optional
//  "OPTIONAL" pill, and a content area below a divider. Used to group wizard fields.
//

import SwiftUI

struct CSSectionCard<Content: View>: View {

    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var isOptional: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CSCardHeader(icon: icon, iconColor: iconColor, title: title,
                         subtitle: subtitle, isOptional: isOptional)

            Divider().padding(.top, 14)

            content.padding(.top, 16)
        }
        // Non-clipping card style: a rounded white background + shadow that mirrors
        // `cardStylePkg`'s visuals, but WITHOUT clipping content — so an open dropdown's
        // list can overflow past the card edge instead of being cut off.
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 10)
        )
    }
}

/// Header row shared by section cards (also usable standalone for compact cards).
struct CSCardHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var isOptional: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(iconColor.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if isOptional { CSOptionalBadge() }
        }
    }
}

struct CSOptionalBadge: View {
    var text: String = "OPTIONAL"
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.systemGray5)))
    }
}
