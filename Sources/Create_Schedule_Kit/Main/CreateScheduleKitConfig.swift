//
//  CreateScheduleKitConfig.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation

public struct CreateScheduleKitConfig: Sendable {

    let orgCode: String
    let isBlobEnabled: Bool
    let dateConfiguration: String
    let encryptionDecryptionKey: String
    let userName: String
    /// Plain (un-encrypted) logged-in user id. Encrypted in-package before APIs that require it (e.g. searchTrainer).
    let userId: String
    /// Plain user type, e.g. "Internal". Encrypted in-package before use.
    let userType: String
    let tokenProvider: @Sendable () -> String?

    public init(
        baseURL: String,
        lxpOPath: String,
        lxpBlobPath: String,
        lxpBlobPath1: String,
        isBlobEnabled: Bool,
        orgCode: String,
        dateConfiguration: String,
        encryptionDecryptionKey: String,
        userName: String,
        userId: String,
        userType: String,
        tokenProvider: @escaping @Sendable () -> String?
    ) {
        APIConst.baseURL = baseURL
        APIConst.lxpOPath = lxpOPath
        APIConst.lxpBlobPath = lxpBlobPath
        APIConst.lxpBlobPath1 = lxpBlobPath1
        self.isBlobEnabled = isBlobEnabled
        self.orgCode = orgCode
        self.dateConfiguration = dateConfiguration
        self.encryptionDecryptionKey = encryptionDecryptionKey
        self.userName = userName
        self.userId = userId
        self.userType = userType
        self.tokenProvider = tokenProvider
    }
}
