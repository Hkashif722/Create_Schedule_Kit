//
//  CreateTrainerTests.swift
//  Create_Schedule_KitTests
//
//  Covers the External-trainer creation path from Step 2: form gating, the `User/Exist`
//  verdict, the `POST user` body, and the created account's mapping onto a Trainer.
//

import Testing
import Foundation
import SwiftUIUtilities
@testable import Create_Schedule_Kit

@Suite struct CreateTrainerTests {

    typealias DM = CreateTrainerDataModel

    init() {
        // The trainer-id encrypt path reads the shared utility environment, which must be
        // configured before use (matches the views' preview setup).
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

    // MARK: - Form gating

    private func validForm() -> CreateTrainerForm {
        CreateTrainerForm(name: "ketone", email: "ketone@gmail.com", mobile: "9898789879")
    }

    @Test func aCompleteFormPassesEveryRule() {
        #expect(validForm().isValid)
        #expect(validForm().validationMessage == nil)
    }

    @Test func everyFieldIsRequired() {
        var form = validForm()
        form.name = ""
        #expect(form.isValid == false)

        form = validForm()
        form.email = ""
        #expect(form.isValid == false)

        form = validForm()
        form.mobile = ""
        #expect(form.isValid == false)
    }

    @Test func theFirstUnmetRuleIsTheOneReported() {
        var form = CreateTrainerForm()
        #expect(form.validationMessage == "Enter the trainer's name.")
        form.name = "ketone"
        #expect(form.validationMessage == "Enter a valid email address.")
        form.email = "ketone@gmail.com"
        #expect(form.validationMessage == "Enter a 10-digit mobile number.")
    }

    @Test(arguments: [
        "ketone@gmail.com",
        "k.etone+ilt@sub.domain.co.uk"
    ])
    func plausibleEmailsAreAccepted(address: String) {
        #expect(CreateTrainerForm.isValidEmail(address))
    }

    @Test(arguments: [
        "",
        "ketone",
        "ketone@",
        "@gmail.com",
        "ketone@gmail",
        "ketone@gmail.c",
        "ketone@@gmail.com",
        "ket one@gmail.com",
        "ketone@.com"
    ])
    func malformedEmailsAreRejected(address: String) {
        #expect(CreateTrainerForm.isValidEmail(address) == false)
    }

    @Test func aNameNeedsMoreThanASingleCharacter() {
        #expect(CreateTrainerForm.isValidName("k") == false)
        #expect(CreateTrainerForm.isValidName("  k  ") == false)
        #expect(CreateTrainerForm.isValidName("ko"))
    }

    // MARK: - Mobile sanitising

    @Test func typedMobilesAreReducedToDigits() {
        #expect(CreateTrainerForm.sanitizedMobile("98987-89879") == "9898789879")
        #expect(CreateTrainerForm.sanitizedMobile("+91 98987 89879") == "9198987898")
        #expect(CreateTrainerForm.sanitizedMobile("abc") == "")
    }

    @Test func theMobileIsCappedAtTheExpectedLength() {
        #expect(CreateTrainerForm.sanitizedMobile("98987898791234") == "9898789879")
    }

    @Test func onlyAFullLengthMobileIsValid() {
        #expect(CreateTrainerForm.isValidMobile("989878987") == false)
        #expect(CreateTrainerForm.isValidMobile("9898789879"))
    }

    @Test func theTrimmedMobileStripsFormattingBeforeItIsSent() {
        let form = CreateTrainerForm(name: "ketone", email: "k@g.com", mobile: "98987-89879")
        #expect(form.trimmedMobile == "9898789879")
    }

    // MARK: - Existence check

    @Test func theRouteMatchesTheDocumentedEndpoint() {
        #expect(DM.UserExistRequest().path == "/api/v1/User/Exist")
        #expect(DM.CreateUserRequest().path == "/api/v1/user")
    }

    @Test func bothLookupFieldsAreEncrypted() throws {
        let payload = DM.UserExistRequest.Payload(
            searchByColumn: EncryptDecryptUtility.shared.newEncryptValueString(
                valueStr: DM.UserExistRequest.mobileColumn
            ),
            searchText: EncryptDecryptUtility.shared.newEncryptValueString(valueStr: "9898789879")
        )
        #expect(payload.searchByColumn != DM.UserExistRequest.mobileColumn)
        #expect(payload.searchText != "9898789879")
        #expect(
            EncryptDecryptUtility.shared.newDecryptString(responseStr: payload.searchByColumn) == "mobile"
        )
        #expect(
            EncryptDecryptUtility.shared.newDecryptString(responseStr: payload.searchText) == "9898789879"
        )
    }

    @Test func theObservedNotFoundResponseMeansTheMobileIsFree() throws {
        let json = #"""
        {"statusCode":0,"message":"NotFound","description":"No record found!","result":null}
        """#
        let response = try JSONDecoder().decode(DM.UserExistResponse.self, from: Data(json.utf8))
        #expect(response.userExists == false)
    }

    @Test func aReturnedRecordMeansTheMobileIsTaken() throws {
        let json = #"""
        {"statusCode":200,"message":"Success","description":"","result":{"id":12194}}
        """#
        let response = try JSONDecoder().decode(DM.UserExistResponse.self, from: Data(json.utf8))
        #expect(response.userExists)
    }

    /// An unrecognised envelope must not read as "free" — a duplicate account is the worse
    /// outcome, and "Select User from System" remains available either way.
    @Test func anUnrecognisedEnvelopeIsTreatedAsTaken() throws {
        let json = #"{"statusCode":500,"message":"Something failed","description":null,"result":null}"#
        let response = try JSONDecoder().decode(DM.UserExistResponse.self, from: Data(json.utf8))
        #expect(response.userExists)
    }

    // MARK: - Create payload

    private func encodeToObject(_ payload: DM.CreateUserPayload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return try #require(object as? [String: Any])
    }

    private func samplePayload() -> DM.CreateUserPayload {
        DM.CreateUserPayload(
            form: validForm(),
            customerCode: "enth",
            now: Date(timeIntervalSince1970: 1_787_798_656.832)
        )
    }

    @Test func theTypedFieldsLandOnTheExpectedKeys() throws {
        let body = try encodeToObject(samplePayload())
        #expect(body["userName"] as? String == "ketone")
        #expect(body["emailId"] as? String == "ketone@gmail.com")
        #expect(body["mobileNumber"] as? String == "9898789879")
        #expect(body["customerCode"] as? String == "enth")
    }

    /// The mobile number doubles as the login id for an external trainer.
    @Test func theMobileNumberIsAlsoSentAsTheUserId() throws {
        let body = try encodeToObject(samplePayload())
        #expect(body["userId"] as? String == "9898789879")
    }

    @Test func theExternalTrainerRoleTripleIsPinned() throws {
        let body = try encodeToObject(samplePayload())
        #expect(body["userRole"] as? String == "ET")
        #expect(body["userType"] as? String == "External")
        #expect(body["userSubType"] as? String == "externalTrainer")
    }

    @Test func theOrgDefaultsMatchTheWebClient() throws {
        let body = try encodeToObject(samplePayload())
        #expect(body["timeZone"] as? String == "(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi")
        #expect(body["currency"] as? String == "Indian Rupee")
        #expect(body["language"] as? String == "English")
    }

    @Test func theAccountIsCreatedActiveWithATenYearWindow() throws {
        let body = try encodeToObject(samplePayload())
        let created = try #require(body["accountCreatedDate"] as? String)
        let expiry = try #require(body["accountExpiryDate"] as? String)
        // Same instant, ten years apart — and `lastModifiedDate` shares the creation stamp.
        #expect(created.hasPrefix("2026-08-27T"))
        #expect(expiry.hasPrefix("2036-08-27T"))
        #expect(created.hasSuffix("Z"))
        #expect(body["lastModifiedDate"] as? String == created)
        #expect(body["isActive"] as? Bool == true)
        #expect(body["isDeleted"] as? Bool == false)
    }

    @Test func theNullFieldsAreSentAsExplicitNulls() throws {
        let body = try encodeToObject(samplePayload())
        for key in ["buddyTrainerId", "mentorId", "hrbpId", "dateOfBirth", "dateIntoRole",
                    "dateOfJoining", "acceptanceDate", "vendorId", "areaId", "groupId",
                    "locationId", "configurationColumn1Id"] {
            #expect(body[key] is NSNull, "\(key) must be an explicit null")
        }
    }

    @Test func allTwentyConfigurationColumnsAreSentEmpty() throws {
        let body = try encodeToObject(samplePayload())
        for index in 1...20 {
            #expect(body["configurationColumn\(index)"] as? String == "",
                    "configurationColumn\(index) must be an empty string")
        }
    }

    @Test func theIdIsZeroSoTheServerCreatesRatherThanUpdates() throws {
        let body = try encodeToObject(samplePayload())
        #expect(body["id"] as? Int == 0)
    }

    // MARK: - Created account → Trainer

    private func createdResponse() throws -> DM.CreateUserResponse {
        let json = #"""
        {
          "id": 12194,
          "userName": "ketone",
          "emailId": "UIvS5eftnEzhVXkHVNoskFGOBoEePlLHuOMc15702Fw=",
          "userId": "1s8JCQPnfBju51UQciJE8g==",
          "mobileNumber": "1s8JCQPnfBju51UQciJE8g==",
          "userType": "External",
          "userSubType": "externalTrainer"
        }
        """#
        return try JSONDecoder().decode(DM.CreateUserResponse.self, from: Data(json.utf8))
    }

    /// The create-schedule payload decrypts `Trainer.id` back into `academyTrainerID`, so the
    /// plain numeric id has to be encrypted on the way in.
    @Test func theNumericIdIsEncryptedToMatchASearchedTrainer() throws {
        let trainer = ScheduleLogisticsDataModel.Trainer(created: try createdResponse(), form: validForm())
        #expect(trainer.id != "12194")
        #expect(EncryptDecryptUtility.shared.newDecryptString(responseStr: trainer.id) == "12194")
    }

    @Test func theEncryptedIdentityFieldsArePassedThroughUntouched() throws {
        let response = try createdResponse()
        let trainer = ScheduleLogisticsDataModel.Trainer(created: response, form: validForm())
        #expect(trainer.emailId == response.emailId)
        #expect(trainer.userId == response.userId)
        #expect(trainer.mobileNumber == response.mobileNumber)
        #expect(trainer.userType == "External")
    }

    /// No composed display string comes back, so the chip and the payload fall back to `name`.
    @Test func theChipFallsBackToTheAccountName() throws {
        let trainer = ScheduleLogisticsDataModel.Trainer(created: try createdResponse(), form: validForm())
        #expect(trainer.nameUserId == nil)
        #expect(trainer.displayName == "ketone")
    }

    @Test func theTypedNameCoversAResponseThatOmitsIt() throws {
        let response = try JSONDecoder().decode(
            DM.CreateUserResponse.self,
            from: Data(#"{"id":12194}"#.utf8)
        )
        let trainer = ScheduleLogisticsDataModel.Trainer(created: response, form: validForm())
        #expect(trainer.name == "ketone")
        #expect(trainer.userType == "External")
    }
}
