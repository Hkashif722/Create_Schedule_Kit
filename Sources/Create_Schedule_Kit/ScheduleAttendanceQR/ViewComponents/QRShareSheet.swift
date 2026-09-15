//
//  QRShareSheet.swift
//  Create_Schedule_Kit
//
//  `UIActivityViewController` for the exported QR file. `ShareLink` would do this in one
//  line, but it is iOS 16+ and this package supports 15.
//

import SwiftUI
import UIKit

struct QRShareSheet: UIViewControllerRepresentable {

    let fileURL: URL
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        // Required on iPad, where the sheet is a popover and needs an anchor.
        controller.popoverPresentationController?.permittedArrowDirections = []
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
