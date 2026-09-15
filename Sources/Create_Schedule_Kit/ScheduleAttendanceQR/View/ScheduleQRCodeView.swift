//
//  ScheduleQRCodeView.swift
//  Create_Schedule_Kit
//
//  The schedule's QR as a card: the code, what it is for, and Download.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct ScheduleQRCodeView: View {

    @StateObject private var viewModel: ScheduleQRCodeViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.ScheduleQRCodeNavModel) {
        _viewModel = StateObject(
            wrappedValue: ScheduleQRCodeViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            code
            Text(viewModel.caption)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            downloadButton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .padding(24)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: Binding(
            get: { viewModel.shareURL != nil },
            set: { if !$0 { viewModel.didFinishSharing() } }
        )) {
            if let url = viewModel.shareURL {
                QRShareSheet(fileURL: url) { viewModel.didFinishSharing() }
            }
        }
    }
}

// MARK: - Pieces
private extension ScheduleQRCodeView {

    var header: some View {
        VStack(spacing: 4) {
            HStack {
                Spacer()
                Button { viewModel.didTapClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(.systemGray6)))
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.title)
                .font(.system(size: 18, weight: .bold))
            Text(viewModel.subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    var code: some View {
        if let image = viewModel.qrImage {
            Image(uiImage: image)
                .interpolation(.none)     // keep the modules crisp when scaled up
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
        } else if viewModel.generationFailed {
            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 28, weight: .semibold))
                Text("QR unavailable")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.secondary)
            .frame(width: 220, height: 220)
        } else {
            ProgressView().frame(width: 220, height: 220)
        }
    }

    var downloadButton: some View {
        CSPrimaryButton(
            title: "Download",
            systemImage: "arrow.down.circle",
            isEnabled: viewModel.isShareEnabled
        ) {
            viewModel.didTapDownload()
        }
    }
}
