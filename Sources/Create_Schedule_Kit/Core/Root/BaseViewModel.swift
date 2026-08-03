//
//  BaseViewModel.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation
import SwiftUIUtilities

// Package-level base class. All module ViewModels inherit from this to get the shared
// event publisher, while still inheriting all of `RoutableViewModel`'s behaviour.
internal class BaseViewModel: RoutableViewModel {
    let eventPublisher = CreateScheduleKitEventPublisher.shared
}
