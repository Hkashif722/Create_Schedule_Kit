import Testing
import Foundation
@testable import Create_Schedule_Kit

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
}

@Suite struct ScheduleDateRulesTests {

    @Test func startSelectionAutoPopulatesEndAndRegistration() {
        let start = date(2026, 8, 20)
        let result = ScheduleDateRules.autoPopulated(forStart: start)
        #expect(result.end == start)
        #expect(result.registrationEnd == start)
    }

    @Test func endMinimumEqualsStart() {
        let start = date(2026, 8, 20)
        #expect(ScheduleDateRules.endMinimum(forStart: start) == start)
    }

    @Test func endIsClampedNotBeforeStart() {
        let start = date(2026, 8, 20)
        let earlier = date(2026, 8, 18)
        let later = date(2026, 8, 25)
        #expect(ScheduleDateRules.clampedEnd(earlier, start: start) == start)
        #expect(ScheduleDateRules.clampedEnd(later, start: start) == later)
    }

    @Test func registrationWindowIsThreeDaysBeforeToStart() {
        let start = date(2026, 8, 20)
        let window = ScheduleDateRules.registrationWindow(forStart: start)
        #expect(window.max == start)
        #expect(window.min == date(2026, 8, 17))   // 20 Aug → 17 Aug
    }
}
