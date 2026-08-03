//
//  CreateScheduleKitEventPublisher.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation
import Combine

// MARK: - Event Publisher
/// Single shared publisher for `CreateScheduleKitEvent`. ViewModels publish through
/// the package-internal `publish(_:)`; the host app subscribes to `events`.
public final class CreateScheduleKitEventPublisher {

    @MainActor public static let shared = CreateScheduleKitEventPublisher()

    private let eventSubject = PassthroughSubject<CreateScheduleKitEvent, Never>()

    public var events: AnyPublisher<CreateScheduleKitEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private init() {}

    internal func publish(_ event: CreateScheduleKitEvent) {
        eventSubject.send(event)
    }
}
