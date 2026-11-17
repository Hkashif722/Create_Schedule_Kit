//
//  WireCrypto.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 03/11/26.
//

import Foundation
import SwiftUIUtilities

// only for CancellationSchedule & DeleteUserNomination, the 2 routes where uat (plain) != prod (AES).
// everything else is AES on both envs, keep it on EncryptDecryptUtility directly
enum WireCrypto {

    static var isEnabled: Bool {
        CreateScheduleKitAPIManager.shared.isEncryptionEnabled
    }

    static func encrypt(_ value: String) -> String {
        guard isEnabled else { return value }
        return EncryptDecryptUtility.shared.newEncryptValueString(valueStr: value)
    }
}
