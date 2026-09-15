//
//  QRCaptureSession.swift
//  Create_Schedule_Kit
//
//  A capture session that does one thing: read QR codes.
//
//  Deliberately not the main app's `AVManager`, which also owns photo, movie and audio
//  capture — its camera use-case attaches a photo output this screen never uses, and its
//  permission handling asks for the microphone, which a package has no business doing.
//  Owning the session here also means the metadata output is attached inside
//  begin/commitConfiguration rather than from a callback after the fact.
//

import AVFoundation
import Foundation

final class QRCaptureSession: NSObject {

    enum Failure: Error {
        case noCamera
        case cannotAddInput
        case cannotAddOutput
    }

    let session = AVCaptureSession()

    /// `startRunning()` blocks, so it never runs on the main thread.
    private let queue = DispatchQueue(label: "com.enthral.createschedulekit.qr.session")
    private var isConfigured = false
    private var latch = QRScanLatch()
    private var onFound: ((String) -> Void)?

    /// Attaches the camera and a QR-only metadata output. Safe to call more than once.
    func configureIfNeeded() throws {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { throw Failure.noCamera }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard session.canAddInput(input) else { throw Failure.cannotAddInput }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { throw Failure.cannotAddOutput }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Set only after the output is attached — the available types are empty before that.
        output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr) ? [.qr] : []

        isConfigured = true
    }

    func start(onFound: @escaping (String) -> Void) {
        self.onFound = onFound
        queue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    /// Re-Scan: clears the latch and resumes delivery.
    func rearm(onFound: @escaping (String) -> Void) {
        latch.rearm()
        start(onFound: onFound)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension QRCaptureSession: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let value = metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .first { $0.type == .qr }?
            .stringValue

        guard let scanned = latch.accept(value) else { return }

        // One QR in front of the lens is one action: stop before handing it over, so the
        // confirmation popup is not racing further frames.
        stop()
        onFound?(scanned)
    }
}
