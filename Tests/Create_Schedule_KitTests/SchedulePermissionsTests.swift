//
//  SchedulePermissionsTests.swift
//  Create_Schedule_KitTests
//
//  Pins the external-trainer ("ET") restriction: view a schedule and mark its attendance,
//  nothing else.
//

import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct SchedulePermissionsTests {

    // MARK: - Role matching

    @Test(arguments: ["ET", "et", "Et", " et ", "eT\n"])
    func theExternalTrainerRoleIsMatchedRegardlessOfCaseOrPadding(role: String) {
        #expect(SchedulePermissions(userRole: role).isExternalTrainer)
    }

    @Test(arguments: ["", "ADMIN", "IT", "ETC", "E", "TRAINER", "External"])
    func everyOtherRoleIsUnrestricted(role: String) {
        let permissions = SchedulePermissions(userRole: role)
        #expect(permissions.isExternalTrainer == false)
        #expect(permissions.canCreateSchedule)
        #expect(permissions.canEditSchedule)
        #expect(permissions.canCancelSchedule)
        #expect(permissions.canNominate)
    }

    /// "ETC" must not match on a prefix — the comparison is whole-string.
    @Test func aRoleThatMerelyStartsWithETIsNotAnExternalTrainer() {
        #expect(SchedulePermissions(userRole: "ETC").isExternalTrainer == false)
        #expect(SchedulePermissions(userRole: "ETL").canEditSchedule)
    }

    // MARK: - The ET capability set

    @Test func anExternalTrainerCannotOwnASchedule() {
        let permissions = SchedulePermissions(userRole: "ET")
        #expect(permissions.canCreateSchedule == false)
        #expect(permissions.canEditSchedule == false)
        #expect(permissions.canCancelSchedule == false)
        #expect(permissions.canNominate == false)
    }

    @Test func anExternalTrainerKeepsViewingAndAttendance() {
        let permissions = SchedulePermissions(userRole: "ET")
        #expect(permissions.canViewSchedule)
        #expect(permissions.canMarkAttendance)
    }

    /// Viewing and marking attendance are never gated on role.
    @Test(arguments: ["ET", "ADMIN", ""])
    func viewingAndAttendanceAreOpenToEveryRole(role: String) {
        let permissions = SchedulePermissions(userRole: role)
        #expect(permissions.canViewSchedule)
        #expect(permissions.canMarkAttendance)
    }

    /// An unconfigured package (previews, tests) reports an empty role and stays unrestricted.
    @Test func anUnconfiguredPackageIsUnrestricted() {
        #expect(SchedulePermissions(userRole: "").isExternalTrainer == false)
    }
}
