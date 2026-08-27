//
//  CreateScheduleKitAPIManager.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation
import NetworkService
import SwiftUIUtilities

public actor CreateScheduleKitAPIManager {

    public static let shared = CreateScheduleKitAPIManager()

    nonisolated(unsafe) private var config: CreateScheduleKitConfig?

    nonisolated internal var getOrgCode: String {
        config?.orgCode ?? ""
    }

    nonisolated internal var isBlobEnabled: Bool {
        config?.isBlobEnabled ?? true
    }

    nonisolated internal var getConfiguaredDate: String {
        config?.dateConfiguration ?? ""
    }

    nonisolated internal var getUserName: String {
        config?.userName ?? ""
    }

    nonisolated internal var getUserId: String {
        config?.userId ?? ""
    }

    nonisolated internal var getUserRole: String {
        config?.userRole ?? ""
    }

    /// Current bearer token (same provider handed to `ApiService`). Used by the plain-text
    /// client for endpoints that return non-JSON bodies.
    nonisolated internal var authToken: String? {
        config?.tokenProvider()
    }

    private init() {}

    // Call this once from the host app
    public func configure(_ config: CreateScheduleKitConfig) {
        self.config = config

        ApiService.shared.setAuthToken(config.tokenProvider)
        APIConfiguration.shared.baseURL = APIConst.baseURL
        self.configureSwiftUIUtilityEnvironment(config)
    }

    private func configureSwiftUIUtilityEnvironment(_ config: CreateScheduleKitConfig) {
        let modelConfiguration = SwiftUtilityConfig(
            encryptionDecryptionKey: config.encryptionDecryptionKey,
            isBlobEnabled: config.isBlobEnabled,
            orgCode: config.orgCode,
            configurableDate: config.dateConfiguration,
            baseURL: APIConst.baseURL,
            lxpOPath: APIConst.lxpOPath,
            lxpBlobPath: APIConst.lxpBlobPath,
            lxpBlobPath1: APIConst.lxpBlobPath1
        )
        SwiftUtilityEnvironment.configure(modelConfiguration)
    }

    // Shared accessor
    public var baseURL: String {
        APIConst.baseURL
    }
}
