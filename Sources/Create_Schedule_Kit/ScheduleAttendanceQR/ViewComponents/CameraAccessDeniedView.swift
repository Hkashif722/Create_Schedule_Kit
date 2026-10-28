//
//  CameraAccessDeniedView.swift
//  Create_Schedule_Kit
//
//  Shown instead of a black preview when the camera cannot be opened. Two reasons reach
//  here: the user refused, or the host app carries no camera usage description — the second
//  is a misconfiguration a package cannot fix, so it degrades rather than crashing.
//

import SwiftUI
import SwiftUIUtilities

struct CameraAccessDeniedView: View {

    let message: String
    /// `nil` when there is nothing the user can do in Settings.
    let onOpenSettings: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.secondary)

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let onOpenSettings {
                Button(action: onOpenSettings) {
                    Text("Open Settings")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(CSTheme.primaryColor)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .overlay(
                            Capsule().stroke(CSTheme.primaryColor, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview("Denied") {
    CameraAccessDeniedView(
        message: "Camera access is off for this app. Turn it on in Settings to scan a QR code.",
        onOpenSettings: {}
    )
}

#Preview("Unavailable") {
    CameraAccessDeniedView(message: "Camera is not available in this app.", onOpenSettings: nil)
}
