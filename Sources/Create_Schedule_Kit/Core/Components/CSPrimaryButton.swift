//
//  CSPrimaryButton.swift
//  Create_Schedule_Kit
//
//  Themed buttons (driven by the host theme via ColorUtility):
//  - CSPrimaryButton:   filled primary  (in-card / sheet CTAs)
//  - CSSecondaryButton: outlined primary (e.g. footer "Back")
//  - CSNavButton:       filled secondary (footer "Next" / "Create Schedule")
//

import SwiftUI
import SwiftUIUtilities

struct CSPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            buttonLabel(title: title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isEnabled ? CSTheme.primaryColor : CSTheme.primaryColor.opacity(0.4))
                .foregroundColor(CSTheme.primaryColor.getDynamicTextColor)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct CSNavButton: View {
    let title: String
    var systemImage: String? = "arrow.right"
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            buttonLabel(title: title, systemImage: systemImage, imageTrailing: true)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isEnabled ? CSTheme.secondaryColor : CSTheme.secondaryColor.opacity(0.4))
                .foregroundColor(CSTheme.secondaryColor.getDynamicTextColor)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
        // no .disabled on purpose, vm toasts whats missing. dead grey btn = QA ticket
        .accessibilityHint(isEnabled ? "" : "Some required fields are incomplete")
    }
}

struct CSSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            buttonLabel(title: title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundColor(CSTheme.primaryColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(CSTheme.primaryColor, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Borderless text action (e.g. "Keep Schedule") — the quiet way out of a destructive sheet.
struct CSPlainTextButton: View {
    let title: String
    var tint: Color = CSTheme.primaryColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.plain)
    }
}

/// Bottom navigation bar: optional outlined "Back" + filled primary action.
struct CSNavFooter: View {
    var showBack: Bool = true
    var nextTitle: String = "Next"
    var nextSystemImage: String? = "arrow.right"
    var isNextEnabled: Bool = true
    var onBack: () -> Void = {}
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if showBack {
                CSSecondaryButton(title: "Back", systemImage: "arrow.left", action: onBack)
            }
            CSNavButton(title: nextTitle, systemImage: nextSystemImage,
                        isEnabled: isNextEnabled, action: onNext)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Shared label

@ViewBuilder
private func buttonLabel(title: String, systemImage: String?, imageTrailing: Bool = false) -> some View {
    HStack(spacing: 8) {
        if let systemImage, !imageTrailing {
            Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
        }
        Text(title).font(.system(size: 16, weight: .semibold))
        if let systemImage, imageTrailing {
            Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
        }
    }
}
