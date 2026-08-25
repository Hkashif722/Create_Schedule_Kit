import Testing
import Foundation
import SwiftUIUtilities
@testable import Create_Schedule_Kit

/// `ScheduleDraft.apply(details:modules:timezones:)` mapping tests — the details → draft
/// conversions the edit flow depends on (dates, 24h→12h times, trainer id round-trip,
/// module/timezone resolution + fallbacks, holidays, coordinator).
@Suite struct ScheduleDraftHydrationTests {

    init() {
        // Trainer-id encryption reads the shared utility environment.
        SwiftUtilityEnvironment.configure(
            SwiftUtilityConfig(
                encryptionDecryptionKey: "preview-key",
                isBlobEnabled: true,
                orgCode: "preview",
                configurableDate: "dd-MM-yyyy",
                baseURL: "",
                lxpOPath: "",
                lxpBlobPath: "",
                lxpBlobPath1: ""
            )
        )
    }

    private func decodeDetails(_ json: String) throws -> EditScheduleDataModel.ScheduleDetailsResponse {
        try JSONDecoder().decode(EditScheduleDataModel.ScheduleDetailsResponse.self, from: Data(json.utf8))
    }

    private func hydratedDraft(
        modules: [ScheduleBasicDetailsDataModel.ModuleItem] = [],
        timezones: [ScheduleBasicDetailsDataModel.TimezoneItem] = []
    ) throws -> ScheduleDraft {
        let details = try decodeDetails(EditScheduleFixtures.detailsJSON)
        let draft = ScheduleDraft()
        draft.apply(details: details, modules: modules, timezones: timezones)
        return draft
    }

    private func day(_ string: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)!
    }

    // MARK: - Step 1 mapping

    @Test func basicIdentityAndDatesHydrate() throws {
        let draft = try hydratedDraft()

        #expect(draft.scheduleCode == "SC6821")
        #expect(draft.course?.id == 57812)
        #expect(draft.course?.title == "Schedule Creation")
        #expect(draft.course?.code == "19372")
        #expect(draft.deliveryMode == .offline)
        #expect(draft.webinarType == nil)
        #expect(draft.startDate == day("2026-08-04"))
        #expect(draft.endDate == day("2026-08-04"))
        #expect(draft.registrationEndDate == day("2026-08-04"))
    }

    @Test func moduleResolvesFromFetchedListWhenPresent() throws {
        let listed = ScheduleBasicDetailsDataModel.ModuleItem(
            id: 46111, title: "19372_Schedule Creation", type: "classroom",
            courseFee: 0, currency: "", category: "Sales", subCategory: "Field", subSubCategory: nil
        )
        let draft = try hydratedDraft(modules: [listed])
        #expect(draft.module?.id == 46111)
        #expect(draft.module?.category == "Sales")
    }

    @Test func moduleFallsBackToSynthesizedItem() throws {
        let draft = try hydratedDraft(modules: [])
        #expect(draft.module?.id == 46111)
        #expect(draft.module?.title == "19372_Schedule Creation")
        #expect(draft.module?.category == nil)
    }

    @Test func timezoneMatchesByValueWithSynthesizedFallback() throws {
        let ist = ScheduleBasicDetailsDataModel.TimezoneItem(
            value: "India Standard Time", code: "IST", offset: 5.5, isdst: false,
            name: "(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi"
        )
        let matched = try hydratedDraft(timezones: [ist])
        #expect(matched.timezone?.code == "IST")

        let fallback = try hydratedDraft(timezones: [])
        // Dropdown selection matches by `id == value`, so the fallback still selects.
        #expect(fallback.timezone?.value == "India Standard Time")
        #expect(fallback.timezone?.name == "India Standard Time")
    }

    @Test func apiTimesConvertToPickerFormatAndRoundTrip() throws {
        let draft = try hydratedDraft()
        // displayTime is the inverse of apiTime — the submit path must reproduce
        // the original 24-hour values exactly.
        #expect(CreateScheduleWizardDataModel.Payload.apiTime(try #require(draft.startTime)) == "19:10")
        #expect(CreateScheduleWizardDataModel.Payload.apiTime(try #require(draft.endTime)) == "19:12")
    }

    @Test func holidaysNormalizeAcrossTheScheduleRange() throws {
        let draft = try hydratedDraft()
        #expect(draft.holidays.count == 1)
        #expect(draft.holidays.first?.isHoliday == false)
    }

    // MARK: - Step 2 mapping

    @Test func venueTrainersAndCoordinatorHydrate() throws {
        let draft = try hydratedDraft()

        #expect(draft.academy?.id == 28)
        #expect(draft.academy?.title == "Mumbai")
        #expect(draft.trainingPlace?.id == 8)
        #expect(draft.trainingPlace?.placeName == "Mumbai")
        #expect(draft.trainingPlace?.accommodationCapacity == "100")
        #expect(draft.trainingPlace?.postalAddress == "J W Marriott Dadar West")
        #expect(draft.trainerType == .internal)
        #expect(draft.coordinatorName == "")
        #expect(draft.contactNumber == "")

        #expect(draft.trainers.count == 1)
        let trainer = try #require(draft.trainers.first)
        #expect(trainer.name == "kashif")
        #expect(trainer.nameUserId == "kashif-kashif (Internal)")
        // Encrypted email preserved verbatim.
        #expect(trainer.emailId == "kodV1wwpC1fAiTRuK2jifcKuE9h5S1AXqBAr2D1V05o=")
        // The stored id must decrypt back to the numeric trainer id — the payload
        // builders rely on this round-trip.
        let decrypted = EncryptDecryptUtility.shared.newDecryptString(responseStr: trainer.id)
        #expect(decrypted == "8973")
    }

    @Test func tagsFeedbackAndCoordinatorMapFromMinimalDetails() throws {
        let json = """
        {"id":1,"tagList":[{"tagId":7,"tag":"Sony"},{"tagId":8,"tag":"Carrier"}],
         "feedbackId":42111,"feedbackName":"Feedback Report",
         "contactPersonName":"kashif","contactNumber":"7498578961"}
        """
        let draft = ScheduleDraft()
        draft.apply(details: try decodeDetails(json), modules: [], timezones: [])

        #expect(draft.tags.map(\.id) == [7, 8])
        #expect(draft.tags.first?.tag == "Sony")
        #expect(draft.feedbackModule?.id == "42111")
        #expect(draft.feedbackModule?.title == "Feedback Report")
        #expect(draft.coordinatorName == "kashif")
        #expect(draft.contactNumber == "7498578961")
    }

    @Test func webinarScheduleMapsDeliveryAndTypeCaseInsensitively() throws {
        let json = """
        {"id":1,"isWebinar":true,"webinarType":"Zoom","webinarAccount":"ENC_ACCOUNT=="}
        """
        let draft = ScheduleDraft()
        draft.apply(details: try decodeDetails(json), modules: [], timezones: [])

        #expect(draft.deliveryMode == .online)
        #expect(draft.webinarType == .zoom)
        #expect(draft.credential?.first?.teamsEmail == "ENC_ACCOUNT==")
    }
}
