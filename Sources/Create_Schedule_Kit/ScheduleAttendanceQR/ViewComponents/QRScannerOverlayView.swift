//
//  QRScannerOverlayView.swift
//  Create_Schedule_Kit
//
//  The reticle over the camera preview: a dimmed surround with a clear window, and four
//  corner brackets that breathe in and out so the frame reads as live rather than static.
//
//  Ported from the schedule module's `ScannerAreaView` / `EdgeRectangleView`, keeping its
//  numbers — a 300↔320pt window on a one-second timer, each bracket a trimmed arc of a
//  rounded rectangle rotated into place.
//
//  Everything is centred by one `ZStack` rather than positioned inside a `GeometryReader`.
//  The reference reads its centre from the reader's size, which excludes the safe-area
//  insets, while the dimming layer ignores them — so the window and the brackets end up
//  centred on two different points.
//

import SwiftUI
import SwiftUIUtilities

struct QRScannerOverlayView: View {

    let caption: String

    @State private var isExpanded = false

    /// One pulse per second; the animation is slightly shorter so it settles before the
    /// next tick.
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    private let rotations: [Double] = [0, 90, 180, 270]

    /// Shared by the window and the brackets, so the arcs sit exactly on the window's
    /// corners. The reference punches a radius-10 hole and draws radius-20 arcs, which
    /// leaves the brackets cutting across the corners.
    private let cornerRadius: CGFloat = 20

    private var side: CGFloat { isExpanded ? 320 : 300 }

    var body: some View {
        ZStack {
            dimmedSurround
            brackets
            captionLabel
        }
        // Applied once, to the whole overlay: the dimming has to cover the notch and the
        // home indicator, and every layer must share that one coordinate space.
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.9)) {
                isExpanded.toggle()
            }
        }
    }

    /// Dimming with the window punched out, so the camera shows through the middle only.
    private var dimmedSurround: some View {
        Rectangle()
            .fill(Color.black.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .frame(width: side, height: side)
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
    }

    /// Four copies of one bracket, rotated into the corners of the same square.
    private var brackets: some View {
        ZStack {
            ForEach(rotations.indices, id: \.self) { index in
                bracket.rotationEffect(.degrees(rotations[index]))
            }
        }
        .frame(width: side, height: side)
    }

    /// One corner: a short arc trimmed out of a rounded rectangle. The trim range shifts
    /// with the pulse, which is what makes the bracket grow and shrink.
    private var bracket: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .trim(from: isExpanded ? 0.35 : 0.34, to: isExpanded ? 0.40 : 0.41)
            .stroke(
                ColorUtility.secondaryColor,
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
    }

    /// Sits below the window and tracks it as it breathes.
    private var captionLabel: some View {
        Text(caption)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .offset(y: side / 2 + 40)
    }
}

#Preview {
    ZStack {
        Color.gray
        QRScannerOverlayView(caption: "Point the camera at the learner's QR code")
    }
    .ignoresSafeArea()
}
