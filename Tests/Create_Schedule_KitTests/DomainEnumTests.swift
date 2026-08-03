import Testing
@testable import Create_Schedule_Kit

@Suite struct DomainEnumTests {

    @Test func webinarCredentialAvailability() {
        #expect(WebinarType.zoom.hasCredentialAPI)
        #expect(WebinarType.teams.hasCredentialAPI)
        #expect(WebinarType.googleMeet.hasCredentialAPI)
        #expect(WebinarType.gotoMeeting.hasCredentialAPI == false)
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
