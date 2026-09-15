//
//  AttendanceQRScannerView.swift
//  Create_Schedule_Kit
//
//  Full-screen camera for scanning a learner's QR. Draws its own close control because it
//  hides the navigation bar to give the preview the whole screen.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct AttendanceQRScannerView: View {

    @StateObject private var viewModel: AttendanceQRScannerViewModel

    init(router: AnyRouter, navModel: NavigationViewModel.AttendanceQRScannerNavModel) {
        _viewModel = StateObject(
            wrappedValue: AttendanceQRScannerViewModel(router: router, navModel: navModel)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            if viewModel.isPreviewVisible {
                QRScannerPreviewView(session: viewModel.captureSession.session)
                    .ignoresSafeArea()
                QRScannerOverlayView(caption: viewModel.caption)
            } else {
                CameraAccessDeniedView(
                    message: viewModel.accessMessage,
                    onOpenSettings: viewModel.offersSettings
                        ? { viewModel.didTapOpenSettings() }
                        : nil
                )
            }

            header

            if viewModel.isPreviewVisible {
                galleryButton
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 28)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
        .loadingOverlayViewPkg(state: viewModel.loadingState)
        .toastViewPkg(toast: $viewModel.toast)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    /// For a QR that was screenshotted or forwarded rather than held up to the camera.
    private var galleryButton: some View {
        Button { viewModel.didTapUploadFromGallery() } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 14, weight: .bold))
                Text("Upload from Gallery")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .frame(height: 48)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            Button { viewModel.didTapClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(viewModel.isPreviewVisible ? .white : .primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(
                            viewModel.isPreviewVisible
                                ? Color.black.opacity(0.35)
                                : Color(.systemGray5)
                        )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(viewModel.attendanceDateText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(viewModel.isPreviewVisible ? .white : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
