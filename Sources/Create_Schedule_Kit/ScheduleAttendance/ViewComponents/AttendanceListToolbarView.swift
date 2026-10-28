//
//  AttendanceListToolbarView.swift
//  Create_Schedule_Kit
//
//  Bulk Mark's list header: the page-size menu and Select all. Lifted from the one-screen
//  version's `listHeader` / `pageSizeMenu`, which the read-only Attendees screen does not use.
//

import SwiftUI
import SwiftUIUtilities

struct AttendanceListToolbarView: View {

    let pageSize: Int
    let pageSizeChoices: [Int]
    let isAllSelected: Bool
    let selectedText: String
    let onChangePageSize: (Int) -> Void
    let onToggleSelectAll: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("Show")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                pageSizeMenu
                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: onToggleSelectAll) {
                    HStack(spacing: 8) {
                        selectionBox
                        Text("Select all")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(selectedText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var pageSizeMenu: some View {
        Menu {
            ForEach(pageSizeChoices, id: \.self) { size in
                Button("\(size)") { onChangePageSize(size) }
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(pageSize)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }

    private var selectionBox: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(isAllSelected ? CSTheme.primaryColor : Color(.systemGray3), lineWidth: 1.8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isAllSelected ? CSTheme.primaryColor : Color.clear)
            )
            .frame(width: 24, height: 24)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(isAllSelected ? 1 : 0)
            )
    }
}
