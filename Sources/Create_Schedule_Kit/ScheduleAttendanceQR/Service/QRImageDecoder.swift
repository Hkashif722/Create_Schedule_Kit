//
//  QRImageDecoder.swift
//  Create_Schedule_Kit
//
//  Reads a QR out of a still image, for the "Upload from Gallery" path — a learner who
//  screenshotted or was sent their QR, or a printed sheet photographed earlier.
//
//  `CIDetector` rather than `VNDetectBarcodesRequest`: it is available on iOS 15 without
//  Vision, and returns the decoded string directly.
//

import CoreImage
import Foundation
import UIKit

enum QRImageDecoder {

    enum Failure: Error, Equatable {
        case imageUnreadable
        /// A picture with no QR in it, or one too small or blurred to decode.
        case noCodeFound
    }

    /// High accuracy: a gallery image is decoded once, off the hot path, so the extra work
    /// is free — and a screenshot scaled down by a messaging app needs it.
    private static let detector = CIDetector(
        ofType: CIDetectorTypeQRCode,
        context: nil,
        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    )

    static func decode(imageAt url: URL) throws -> String {
        guard let image = UIImage(contentsOfFile: url.path) else { throw Failure.imageUnreadable }
        return try decode(image)
    }

    static func decode(_ image: UIImage) throws -> String {
        guard let ciImage = CIImage(image: image) else { throw Failure.imageUnreadable }

        let features = detector?.features(in: ciImage) ?? []
        let payloads = features
            .compactMap { $0 as? CIQRCodeFeature }
            .compactMap { $0.messageString }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        // A photo of a noticeboard can hold several QRs; the first readable one is the one
        // the user framed.
        guard let payload = payloads.first else { throw Failure.noCodeFound }
        return payload
    }
}
