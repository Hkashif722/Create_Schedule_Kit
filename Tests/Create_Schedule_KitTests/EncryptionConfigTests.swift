//
//  EncryptionConfigTests.swift
//  Create_Schedule_KitTests
//

import Foundation
import Testing
@testable import Create_Schedule_Kit

@Suite("UAT host -> encryption off")
struct EncryptionConfigTests {

    @Test(arguments: [
        "https://uat.gogetempowered.com",
        "https://uat.gogetempowered.com/",
        "https://UAT.gogetempowered.com"
    ])
    func uatHostIsUAT(_ baseURL: String) {
        #expect(APIConst.isUATHost(baseURL))
    }

    // client uats (khaitancouat etc) are other backends, still AES
    @Test(arguments: [
        "https://api.gogetempowered.com",
        "https://gogetempowered.com",
        "https://khaitancouat.gogetempowered.com",
        "https://preprod.gogetempowered.com",
        ""
    ])
    func everythingElseIsProd(_ baseURL: String) {
        #expect(!APIConst.isUATHost(baseURL))
    }

    @Test func noConfigKeepsEncryptionOn() {
        #expect(WireCrypto.isEnabled)
    }
}
