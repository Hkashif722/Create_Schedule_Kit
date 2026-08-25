//
//  HolidaysSheetView.swift
//  Create_Schedule_Kit
//
//  Bottom sheet listing each day in the schedule range to mark as a holiday.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct HolidaysSheetView: View {

    @StateObject private var viewModel: HolidaysSheetViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.HolidaysSheetNavModel) {
        _viewModel = StateObject(
            wrappedValue: HolidaysSheetViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.days) { day in
                        HolidayRowView(
                            day: day,
                            lockCaption: viewModel.lockCaption(for: day),
                            onToggle: { viewModel.toggle(day) },
                            onLabelChange: { viewModel.updateLabel(day, $0) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            CSPrimaryButton(title: "Save holidays") { viewModel.save() }
                .padding()
        }
        .toastViewPkg(toast: $viewModel.toast)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set Holidays")
                    .font(.system(size: 18, weight: .bold))
                Text("Manage holidays for the schedule.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { viewModel.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
}
