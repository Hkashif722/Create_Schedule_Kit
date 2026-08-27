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
    /// The logged-in user's role code, e.g. "ET" for an external trainer. Drives what the
    /// package lets them do — see `SchedulePermissions`.
    let userRole: String
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
        userRole: String,
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
        self.userRole = userRole
        self.tokenProvider = tokenProvider
    }
}
