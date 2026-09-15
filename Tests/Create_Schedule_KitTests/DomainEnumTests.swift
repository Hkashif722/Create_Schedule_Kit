import Testing
@testable import Create_Schedule_Kit

@Suite struct DomainEnumTests {

    @Test func webinarCredentialAvailability() {
        #expect(WebinarType.zoom.hasCredentialAPI)
        #expect(WebinarType.teams.hasCredentialAPI)
        #expect(WebinarType.googleMeet.hasCredentialAPI)
        #expect(WebinarType.gotoMeeting.hasCredentialAPI == false)
    }

    /// The value the create body sends, taken from captured web bodies. Deliberately not
    /// derived from `rawValue`: the server's values follow no single casing rule.
    @Test func webinarApiValuesFollowTheWebsBodies() {
        #expect(WebinarType.teams.apiValue == "TEAMS")
        #expect(WebinarType.zoom.apiValue == "zoom")
        #expect(WebinarType.googleMeet.apiValue == "googlemeet")
        #expect(WebinarType.gotoMeeting.apiValue == "gotomeeting")
    }

    /// Every provider but Teams is plain lowercase. That single exception is why the
    /// values are a table rather than `rawValue.lowercased()`.
    @Test func onlyTeamsBreaksTheLowercaseRule() {
        let outliers = WebinarType.allCases.filter { $0.apiValue != $0.apiValue.lowercased() }
        #expect(outliers == [.teams])
    }

    @Test func trainerTypeApiValueIsCapitalised() {
        #expect(TrainerType.internal.apiValue == "Internal")
        #expect(TrainerType.external.apiValue == "External")
        #expect(TrainerType.consultant.apiValue == "Consultant")
    }

    @Test func deliveryModeTitles() {
        #expect(DeliveryMode.online.displayTitle == "Online")
        #expect(DeliveryMode.offline.displayTitle == "Offline")
    }
}
