import Foundation
import Testing
@testable import Create_Schedule_Kit

@Suite struct ScheduleCodeEditingPolicyTests {

    private func response(_ value: String?) throws -> ScheduleListDataModel.ConfigValueResponse {
        let object: [String: Any] = ["value": value ?? NSNull()]
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(ScheduleListDataModel.ConfigValueResponse.self, from: data)
    }

    @Test func usesASCFEConfigurationEndpoint() {
        let request = ScheduleListDataModel.GetConfigValueRequest(
            key: ScheduleCodeEditingPolicy.configurationCode
        )

        #expect(ScheduleCodeEditingPolicy.configurationCode == "ASCFE")
        #expect(request.path.hasSuffix("/ConfigurableParameters/GetValue/ASCFE"))
    }

    @Test func explicitYesEnablesScheduleCodeEditing() throws {
        #expect(ScheduleCodeEditingPolicy.isEnabled(by: try response("Yes")))
        #expect(ScheduleCodeEditingPolicy.isEnabled(by: try response(" yes ")))
    }

    @Test(arguments: ["No", "", nil] as [String?])
    func disabledOrMissingValuesKeepScheduleCodeLocked(_ value: String?) throws {
        #expect(ScheduleCodeEditingPolicy.isEnabled(by: try response(value)) == false)
    }

    @Test func failedLookupKeepsScheduleCodeLocked() {
        #expect(ScheduleCodeEditingPolicy.isEnabled(by: nil) == false)
    }
}
