//
//  QRScannerPreviewView.swift
//  Create_Schedule_Kit
//
//  The camera preview. Owns no state of its own — the session is created by the view model
//  so it survives SwiftUI rebuilding this view.
//

import AVFoundation
import SwiftUI

struct QRScannerPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    /// A `UIView` whose backing layer *is* the preview layer, so it resizes with the view
    /// instead of needing a frame kept in sync by hand.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // Safe by construction: `layerClass` above guarantees the type.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
