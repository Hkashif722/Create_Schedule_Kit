//
//  ScheduleTabBarView.swift
//  Create_Schedule_Kit
//
//  Underlined Upcoming/Ongoing/Completed tab bar for the Scheduler screen.
//

import SwiftUI
import SwiftUIUtilities

struct ScheduleTabBarView: View {

    @Binding var selection: ScheduleTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleTab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                Button { selection = tab } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSelected ? ColorUtility.primaryColor : .secondary)
                        Rectangle()
                            .fill(isSelected ? ColorUtility.primaryColor : Color.clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ScheduleTabBarView(selection: .constant(.upcoming))
}
