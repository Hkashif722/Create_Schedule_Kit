import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct TeamsLinkPolicyTests {

    private func response(_ value: String?) throws -> ScheduleListDataModel.ConfigValueResponse {
        let object: [String: Any] = ["value": value ?? NSNull()]
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(ScheduleListDataModel.ConfigValueResponse.self, from: data)
    }

    @Test func usesATPTLWCSConfigurationEndpoint() {
        let request = ScheduleListDataModel.GetConfigValueRequest(
            key: TeamsLinkPolicy.configurationCode
        )

        #expect(TeamsLinkPolicy.configurationCode == "ATPTLWCS")
        #expect(request.path.hasSuffix("/ConfigurableParameters/GetValue/ATPTLWCS"))
    }

    @Test(arguments: ["Yes", " yes ", "YES"])
    func explicitYesUnlocksTheTeamsLink(_ value: String) throws {
        #expect(TeamsLinkPolicy.isEnabled(by: try response(value)))
    }

    @Test(arguments: ["No", "", "Maybe", nil] as [String?])
    func disabledOrMissingValuesKeepTheTeamsLinkHidden(_ value: String?) throws {
        #expect(TeamsLinkPolicy.isEnabled(by: try response(value)) == false)
    }

    @Test func failedLookupKeepsTheTeamsLinkHidden() {
        #expect(TeamsLinkPolicy.isEnabled(by: nil) == false)
    }

    @Test func teamsLinkGateIsNotTheScheduleCodeGate() {
        #expect(TeamsLinkPolicy.configurationCode != ScheduleCodeEditingPolicy.configurationCode)
    }
}
