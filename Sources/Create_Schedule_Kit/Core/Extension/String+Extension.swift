//
//  String+Extension.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation
import SwiftUIUtilities

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

extension String {

    /// This value in the form the API expects it: encrypted.
    ///
    /// Some of these values reach us already encrypted (anything read straight off a server
    /// response, or scanned from a QR) and some arrive in the clear (the host's stored
    /// mobile number). Encrypting an already-encrypted value produces a string the server
    /// cannot read, so the encrypted case is detected first — a value that decrypts to
    /// something is already encrypted and is passed through.
    ///
    /// Empty stays empty: there is nothing to protect, and the key still has to go out.
    var encryptedForWire: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let decrypted = EncryptDecryptUtility.shared.newDecryptString(responseStr: trimmed)
        guard decrypted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return trimmed
        }
        return EncryptDecryptUtility.shared.newEncryptValueString(valueStr: trimmed)
    }
}
