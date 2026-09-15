//
//  WireEncryptionTests.swift
//  Create_Schedule_KitTests
//
//  `encryptedForWire` has one job with two inputs: values that arrive in the clear (the
//  host's stored mobile number) and values that arrive already encrypted (anything read off
//  a response or scanned from a QR). Encrypting the second kind again sends the server a
//  string it cannot read, which is the failure this suite exists to prevent.
//

import Testing
import Foundation
import SwiftUIUtilities
@testable import Create_Schedule_Kit

@Suite struct WireEncryptionTests {

    init() {
        SwiftUtilityEnvironment.configure(
            SwiftUtilityConfig(
                encryptionDecryptionKey: "preview-key",
                isBlobEnabled: true,
                orgCode: "preview",
                configurableDate: "dd-MM-yyyy",
                baseURL: "",
                lxpOPath: "",
                lxpBlobPath: "",
                lxpBlobPath1: ""
            )
        )
    }

    private func decrypt(_ value: String) -> String {
        EncryptDecryptUtility.shared.newDecryptString(responseStr: value)
    }

    @Test func aPlainNumberIsEncrypted() {
        let wire = "6536378964".encryptedForWire

        #expect(wire != "6536378964")
        #expect(decrypt(wire) == "6536378964")
    }

    /// The regression this guards: double-encrypting leaves a value that decrypts to
    /// another ciphertext rather than to the number.
    @Test func anAlreadyEncryptedValueIsLeftAlone() {
        let encrypted = EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "6536378964")
        let wire = encrypted.encryptedForWire

        #expect(wire == encrypted)
        #expect(decrypt(wire) == "6536378964")
    }

    /// Running it twice must be the same as running it once — the mark payload is rebuilt
    /// on every scan.
    @Test func theRuleIsIdempotent() {
        let once = "6536378964".encryptedForWire
        #expect(once.encryptedForWire == once)
    }

    @Test(arguments: ["", "   "])
    func nothingToEncryptStaysEmpty(_ raw: String) {
        // An encrypted empty string is a non-empty ciphertext, which would read as a real
        // number server-side.
        #expect(raw.encryptedForWire == "")
    }

    @Test func surroundingWhitespaceIsNotEncryptedIntoTheValue() {
        #expect(decrypt("  6536378964 ".encryptedForWire) == "6536378964")
    }
}
