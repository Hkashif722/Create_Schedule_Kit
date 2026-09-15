//
//  AttendanceUsersListView.swift
//  Create_Schedule_Kit
//
//  The attendee list, shared by Bulk Mark (selectable) and Attendees (read-only). Lifted
//  from the one-screen version's `userList` so both screens page, empty out and load more
//  identically.
//

import SwiftUI
import SwiftUIUtilities

struct AttendanceUsersListView: View {

    let items: [AttendanceDataModel.AttendanceUser]
    let isLoading: Bool
    let isLoadingMore: Bool
    let isSelectable: Bool
    let canDelete: Bool
    let emptyMessage: String
    let emptyIcon: String
    let isSelected: (AttendanceDataModel.AttendanceUser) -> Bool
    let onTap: (AttendanceDataModel.AttendanceUser) -> Void
    let onView: (AttendanceDataModel.AttendanceUser) -> Void
    let onDelete: (AttendanceDataModel.AttendanceUser) -> Void
    let onReachEnd: (AttendanceDataModel.AttendanceUser) -> Void

    var body: some View {
        if isLoading && items.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
        } else if items.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 0) {
                ForEach(items) { user in
                    AttendanceUserRowView(
                        user: user,
                        isSelected: isSelected(user),
                        canDelete: canDelete,
                        isSelectable: isSelectable,
                        onTap: { onTap(user) },
                        onView: { onView(user) },
                        onDelete: { onDelete(user) }
                    )
                    .onAppear { onReachEnd(user) }

                    if user.id != items.last?.id {
                        // Aligned with the text column: 14 inset + avatar + spacing, plus
                        // the checkbox column on the selectable screen.
                        Divider().padding(.leading, isSelectable ? 92 : 68)
                    }
                }
                if isLoadingMore {
                    ProgressView().padding(.vertical, 16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: emptyIcon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.secondary)
            Text(emptyMessage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
