//
//  TrainerSourceMenuField.swift
//  Create_Schedule_Kit
//
//  Step 2's Trainer field while Trainer Type is External and no source has been chosen yet.
//  Reads as a disabled search box; tapping it drops a two-option menu — search the existing
//  directory, or create a brand-new external trainer.
//
//  The menu is an overlay rather than a sheet or a `Menu`, so it matches the venue/tag
//  dropdowns on the same card. Its host must give this field a higher `zIndex` than the
//  content below it.
//

import SwiftUI
import SwiftUIUtilities

/// Where an external trainer comes from.
enum TrainerSource: CaseIterable, Identifiable {
    case existingUser
    case newTrainer

    var id: Self { self }

    var title: String {
        switch self {
        case .existingUser: return "Select User from System"
        case .newTrainer:   return "Create New Trainer"
        }
    }

    var subtitle: String {
        switch self {
        case .existingUser: return "Search existing users in the system"
        case .newTrainer:   return "Add trainer details"
        }
    }

    var icon: String {
        switch self {
        case .existingUser: return "magnifyingglass"
        case .newTrainer:   return "person.crop.circle.badge.plus"
        }
    }

    /// Searching is the primary path; creating is the secondary one. Both come from the host
    /// theme rather than the mock's literal blue/green.
    var tint: Color {
        switch self {
        case .existingUser: return ColorUtility.primaryColor
        case .newTrainer:   return ColorUtility.secondaryColor
        }
    }
}

struct TrainerSourceMenuField: View {

    let placeholder: String
    @Binding var isMenuOpen: Bool
    let onSelect: (TrainerSource) -> Void

    var body: some View {
        field
            .overlay(alignment: .bottomLeading) {
                Group {
                    if isMenuOpen { menu }
                }
                // Hangs the menu off the control's bottom edge without a magic offset —
                // the same alignment trick `DropDownView` uses for the other dropdowns
                // on this card.
                .alignmentGuide(.bottom) { $0[.top] }
            }
    }
}

// MARK: - Sub-views
private extension TrainerSourceMenuField {

    var field: some View {
        Button {
            isMenuOpen.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isMenuOpen ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .frame(height: 45)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isMenuOpen ? ColorUtility.primaryColor : Color(.systemGray4), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isMenuOpen)
    }

    var menu: some View {
        VStack(spacing: 0) {
            ForEach(Array(TrainerSource.allCases.enumerated()), id: \.element.id) { index, source in
                if index > 0 { Divider() }
                row(source)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        )
        .transition(.opacity)
    }

    func row(_ source: TrainerSource) -> some View {
        Button {
            isMenuOpen = false
            onSelect(source)
        } label: {
            HStack(spacing: 12) {
                // A filled badge rather than a bare glyph: `secondaryColor` can be a pale
                // tint, which is unreadable as a foreground but fine as a background with
                // the theme's contrasting text color on top.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(source.tint)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: source.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(source.tint.getDynamicTextColor)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(.primary)
                    Text(source.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 6) {
        CSFieldLabel(title: "Trainer name", isRequired: true)
        TrainerSourceMenuField(
            placeholder: "Trainer Name",
            isMenuOpen: .constant(true),
            onSelect: { _ in }
        )
    }
    .padding()
    .frame(height: 260, alignment: .top)
}
