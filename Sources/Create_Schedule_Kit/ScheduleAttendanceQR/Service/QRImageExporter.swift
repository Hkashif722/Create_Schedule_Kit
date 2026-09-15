//
//  QRImageExporter.swift
//  Create_Schedule_Kit
//
//  "Download" for a QR the device generated.
//
//  It writes a PNG to the temporary directory and hands back the URL for a share sheet,
//  rather than writing to Photos. `UIImageWriteToSavedPhotosAlbum` requires
//  `NSPhotoLibraryAddUsageDescription`, which a package cannot declare and the host does
//  not carry — the call would trap. A share sheet reaches Save Image, AirDrop, Files, Mail
//  and Print, and needs no permission at all.
//

import Foundation
import UIKit

enum QRImageExporter {

    enum Failure: Error, Equatable {
        case pngEncodingFailed
        case writeFailed
    }

    /// `ScheduleQR_SC9202_2026-09-09.png` — named so a printed or forwarded copy says which
    /// schedule and which day it belongs to.
    static func fileName(scheduleCode: String, date: Date) -> String {
        let code = scheduleCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let day = dayFormatter.string(from: date)
        let stem = code.isEmpty ? "ScheduleQR_\(day)" : "ScheduleQR_\(code)_\(day)"
        return "\(stem).png"
    }

    /// Writes the image and returns a file URL. A file URL rather than the `UIImage` itself
    /// so Files, Mail and Print get a real filename and extension.
    static func export(_ image: UIImage, scheduleCode: String, date: Date) throws -> URL {
        guard let data = image.pngData() else { throw Failure.pngEncodingFailed }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(scheduleCode: scheduleCode, date: date))
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw Failure.writeFailed
        }
        return url
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
