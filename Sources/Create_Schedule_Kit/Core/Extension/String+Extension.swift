//
//  String+Extension.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation

extension String {

    /// Returns the localized string for this key from the package bundle.
    var localized: String {
        NSLocalizedString(self, bundle: .createScheduleKitBundle, comment: "")
    }

    /// Converts a Base64-encoded string to `Data`, first stripping any surrounding quotes
    /// and whitespace/newlines, and ignoring non-Base64 characters. Used to decode encrypted
    /// API response strings before decryption (`decryptAndDecodeNew`).
    var base64DecodedDataPkg: Data? {
        let cleaned = trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters)
    }
}
