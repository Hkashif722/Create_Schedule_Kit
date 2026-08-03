//
//  BundleToken.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation
import class Foundation.Bundle

private class BundleToken {}

extension Foundation.Bundle {
    static let createScheduleKitBundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }()
}
