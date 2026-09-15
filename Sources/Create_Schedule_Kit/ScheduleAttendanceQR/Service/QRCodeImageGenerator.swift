//
//  QRCodeImageGenerator.swift
//  Create_Schedule_Kit
//
//  Renders a payload as a QR image with CoreImage. Nothing on the server produces these —
//  the trainer's device is the generator.
//
//  Two deliberate differences from the reference implementation, which encodes the JSON as
//  `.ascii` and returns nothing on failure: this uses UTF-8, so a course name with an
//  accent or a rupee sign still produces a QR; and it throws, so a failure surfaces instead
//  of leaving a card on a loading placeholder forever.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum QRCodeImageGenerator {

    enum Failure: Error, Equatable {
        case encodingFailed
        /// The payload is past what a QR can hold at this correction level.
        case payloadTooLarge
        case renderingFailed
    }

    /// Medium correction — the reference's level, and enough for a printed sheet that picks
    /// up a scuff or two.
    private static let correctionLevel = "M"

    /// Scale applied before rasterising: CoreImage emits one pixel per module, which is a
    /// blurry mess once SwiftUI stretches it.
    private static let scale: CGFloat = 12

    static func image<Payload: Encodable>(for payload: Payload) throws -> UIImage {
        let data = try encode(payload)

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel

        guard let output = filter.outputImage else { throw Failure.payloadTooLarge }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            throw Failure.renderingFailed
        }
        return UIImage(cgImage: cgImage)
    }

    static func encode<Payload: Encodable>(_ payload: Payload) throws -> Data {
        guard let data = try? JSONEncoder().encode(payload) else { throw Failure.encodingFailed }
        return data
    }
}
