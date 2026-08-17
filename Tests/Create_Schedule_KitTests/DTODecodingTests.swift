import Testing
import Foundation
@testable import Create_Schedule_Kit

@Suite struct DTODecodingTests {

    private let decoder = JSONDecoder()

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder.decode(type, from: Data(json.utf8))
    }

    // MARK: - Step 1

    @Test func scheduleCodeDecodesAsBareString() throws {
        let code = try decode(String.self, "\"SC6477\"")
        #expect(code == "SC6477")
    }

    @Test func courseTypeAheadDecodes() throws {
        let json = """
        [{"id":16392,"title":"TechSyss","code":"4225"},
         {"id":16733,"title":"tesst","code":"4734"}]
        """
        let courses = try decode([ScheduleBasicDetailsDataModel.Course].self, json)
        #expect(courses.count == 2)
        #expect(courses[0].code == "4225")
        #expect(courses[0].description == "TechSyss")
    }

    @Test func modulesByCourseDecodes() throws {
        let json = """
        [{"id":19785,"title":"8729_Test ILT006","type":"classroom","courseFee":0,
          "currency":"","category":"-","subCategory":"-","subSubCategory":"-"}]
        """
        let modules = try decode([ScheduleBasicDetailsDataModel.ModuleItem].self, json)
        #expect(modules.first?.id == 19785)
        #expect(modules.first?.type == "classroom")
    }

    @Test func timezonesDecode() throws {
        let json = """
        [{"value":"India Standard Time","code":"IST","offset":5.5,"isdst":false,
          "name":"(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi"}]
        """
        let zones = try decode([ScheduleBasicDetailsDataModel.TimezoneItem].self, json)
        #expect(zones.first?.code == "IST")
        #expect(zones.first?.offset == 5.5)
        #expect(zones.first?.id == "India Standard Time")
    }

    @Test func credentialKeepsEncryptedFieldsOpaqueAndNullUsername() throws {
        let json = """
        {"id":1043,"teamsEmail":"BWwD64UitjMTxa9EAEBLALDp7CQFfmGKqXmbjl9Vq/g=",
         "username":null,"isDefault":0}
        """
        let cred = try decode(ScheduleBasicDetailsDataModel.Credential.self, json)
        #expect(cred.id == 1043)
        #expect(cred.username == nil)
        // Encrypted value preserved verbatim (never decoded into structured types).
        #expect(cred.teamsEmail == "BWwD64UitjMTxa9EAEBLALDp7CQFfmGKqXmbjl9Vq/g=")
    }

    // MARK: - Step 2

    @Test func academyTypeAheadDecodes() throws {
        let json = """
        [{"id":35,"title":"puru1","type":null},{"id":72,"title":"pun","type":null}]
        """
        let academies = try decode([ScheduleLogisticsDataModel.Academy].self, json)
        #expect(academies.count == 2)
        #expect(academies[0].description == "puru1")
    }

    @Test func trainingPlaceDecodesAndExposesAutoFillFields() throws {
        let json = """
        [{"id":5,"placeCode":null,"cityname":"pune","placeName":"pune",
          "accommodationCapacity":"100","postalAddress":"Karve Nagar","contactNumber":"123","contactPerson":"Ravi"}]
        """
        let places = try decode([ScheduleLogisticsDataModel.TrainingPlace].self, json)
        #expect(places.first?.contactPerson == "Ravi")
        #expect(places.first?.contactNumber == "123")
        #expect(places.first?.description == "pune")
    }

    @Test func trainerDecodesWithEncryptedOpaqueFields() throws {
        let json = """
        [{"id":"MoYJXCilEDcIVIgWBLaQug==","name":"Lms Demo ",
          "emailId":"/0HhyvfUHHWMFTMKH7lkJNvEt0/MY+iBr74DGkFBd30=",
          "userId":"Ozm/YG+OIGKbDwKuQvve4w==","profilePicture":"profilePicture/other/o4.png",
          "mobileNumber":"d4YYwgIrkYKuURk4cxrgXw==","userType":"Internal","nameUserId":"Lms Demo  - zivame"}]
        """
        let trainers = try decode([ScheduleLogisticsDataModel.Trainer].self, json)
        #expect(trainers.first?.id == "MoYJXCilEDcIVIgWBLaQug==")
        #expect(trainers.first?.displayName == "Lms Demo  - zivame")
    }

    @Test func tagsDecode() throws {
        let json = """
        [{"id":3,"tag":"Lloyd","tagCode":null,"isActive":false},
         {"id":6,"tag":"Samsung","tagCode":null,"isActive":false}]
        """
        let tags = try decode([ScheduleLogisticsDataModel.Tag].self, json)
        #expect(tags.count == 2)
        #expect(tags[1].description == "Samsung")
    }

    @Test func coordinatorUserDecodesWithEncryptedOpaqueFields() throws {
        let json = """
        [{"id":"5MuV9uilMng5813CFFEKlA==","dB_UserId":"sUEd6Xk0Ky8Um6HzqgcWDQ==","name":"kashif",
          "emailId":"kodV1wwpC1fAiTRuK2jifcKuE9h5S1AXqBAr2D1V05o=","userId":"INISu97c5utzCRj1Jkpsiw==",
          "profilePicture":"profilePicture/male/m2.png","mobileNumber":"7I9tamHII6yo/7E7wLNGnQ==",
          "userType":"Internal","nameUserId":null,"isDeleted":false,"areaId":null,"businessId":null,
          "locationId":null,"groupId":null,"userMasterId":8973}]
        """
        let users = try decode([ScheduleLogisticsDataModel.CoordinatorUser].self, json)
        #expect(users.first?.name == "kashif")
        #expect(users.first?.userMasterId == 8973)
        // Encrypted values preserved verbatim.
        #expect(users.first?.mobileNumber == "7I9tamHII6yo/7E7wLNGnQ==")
        #expect(users.first?.description == "kashif")
    }

    // MARK: - Attendance / nominee list

    /// Verbatim `GetUsersForAttendance` row. The real response carries several keys neither
    /// model declares (`referenceRequestID`, `requestCode`, `noticePeriod`, `config9`,
    /// `division`, `userprofile`) — decoding must tolerate them.
    private static let attendanceRowJSON = """
    [{"id":11892,"scheduleID":3883,"referenceRequestID":null,"requestCode":null,
      "userId":"anu","userName":"anu","emailId":"anu@gmail.com","mobileNumber":"xxxxxxxxxx",
      "status":"True","isPresent":false,"moduleID":46047,"courseID":57680,
      "trainingRequestStatus":"Registered","attendanceStatus":null,"noticePeriod":null,
      "overAllStatus":"Completed","attendanceDate":null,"config9":null,"division":null,
      "userprofile":null}]
    """

    @Test func attendanceUserDecodesFromLiveResponse() throws {
        let users = try decode([AttendanceDataModel.AttendanceUser].self, Self.attendanceRowJSON)
        let user = try #require(users.first)
        #expect(user.id == 11892)
        #expect(user.scheduleID == 3883)
        #expect(user.moduleID == 46047)
        #expect(user.courseID == 57680)
        #expect(user.isPresent == false)
        #expect(user.overAllStatus == "Completed")
        #expect(user.attendanceStatus == nil)
        // `userId` is a plain login name, not an encrypted value.
        #expect(user.userId == "anu")
        #expect(user.displayName == "anu")
        #expect(user.initials == "A")
    }

    @Test func nomineeDecodesFromTheSameResponse() throws {
        let nominees = try decode([ScheduleDetailDataModel.Nominee].self, Self.attendanceRowJSON)
        let nominee = try #require(nominees.first)
        #expect(nominee.id == 11892)
        #expect(nominee.userId == "anu")
        #expect(nominee.displayName == "anu")
        #expect(nominee.trainingRequestStatus == "Registered")
        #expect(nominee.isConfirmed)          // status "True"
        #expect(nominee.statusText == "Confirmed")
    }

    // MARK: - Edit schedule

    @Test func scheduleDetailsByIdDecodes() throws {
        let details = try decode(EditScheduleDataModel.ScheduleDetailsResponse.self, EditScheduleFixtures.detailsJSON)
        #expect(details.id == 3892)
        #expect(details.scheduleCode == "SC6821")
        #expect(details.moduleId == 46111)
        #expect(details.courseID == 57812)
        #expect(details.startTime == "19:10")
        #expect(details.seatCapacity == "100")
        #expect(details.scheduleCapacity == 100)
        #expect(details.timezone == "India Standard Time")
        #expect(details.trainerList?.count == 1)
        #expect(details.trainerList?.first?.academyTrainerID == 8973)
        // Encrypted trainer email preserved verbatim.
        #expect(details.trainerList?.first?.trainerEmail == "kodV1wwpC1fAiTRuK2jifcKuE9h5S1AXqBAr2D1V05o=")
        #expect(details.holidayList?.count == 1)
        #expect(details.holidayList?.first?.isHoliday == false)
        // Unmodelled shapes decode as JSONValue for verbatim echo-back. Explicit JSON
        // nulls decode as nil on optionals; the update payload re-emits them as null.
        #expect(details.createdBy == .string("LMS Admin"))
        #expect(details.topicList == .array([]))
        #expect(details.teamsScheduleDetails == nil)
    }

    // MARK: - Step 3

    @Test func getModuleDataDecodesWrapperAndMapsToFeedbackModule() throws {
        let json = """
        {"data":[
          {"id":42111,"name":"Feedback Report 3","moduleType":"Feedback","courseType":"Feedback",
           "isActive":true,"description":"data","creditPoints":null,"lcmsId":41271,
           "isMultilingual":false,"multilingualLCMSId":[],"userName":"pranita","createdBy":8702,
           "areaId":17,"businessId":26,"groupId":10,"locationId":6,"userCreated":true,"isNegativeMarking":null},
          {"id":42110,"name":"Feedback Report 2","moduleType":"Feedback","courseType":"Feedback",
           "isActive":true,"description":"Metada","creditPoints":null,"lcmsId":41270,
           "isMultilingual":false,"multilingualLCMSId":[],"userName":"pranita","createdBy":8702,
           "areaId":17,"businessId":26,"groupId":10,"locationId":6,"userCreated":true,"isNegativeMarking":null},
          {"id":42109,"name":"Feedback Report 1","moduleType":"Feedback","courseType":"Feedback",
           "isActive":true,"description":"data","creditPoints":null,"lcmsId":41269,
           "isMultilingual":false,"multilingualLCMSId":[],"userName":"pranita","createdBy":8702,
           "areaId":17,"businessId":26,"groupId":10,"locationId":6,"userCreated":true,"isNegativeMarking":null},
          {"id":42063,"name":"feedback reset","moduleType":"Feedback","courseType":"Feedback",
           "isActive":true,"description":"data","creditPoints":null,"lcmsId":41223,
           "isMultilingual":false,"multilingualLCMSId":[],"userName":"LMS Admin","createdBy":9868,
           "areaId":124,"businessId":16,"groupId":62,"locationId":5,"userCreated":true,"isNegativeMarking":null},
          {"id":42059,"name":"reset","moduleType":"Feedback","courseType":"Feedback",
           "isActive":true,"description":"data","creditPoints":null,"lcmsId":41219,
           "isMultilingual":false,"multilingualLCMSId":[],"userName":"LMS Admin","createdBy":9868,
           "areaId":124,"businessId":16,"groupId":62,"locationId":5,"userCreated":true,"isNegativeMarking":null}
        ],"totalRecords":149}
        """
        let response = try decode(ScheduleFeedbackDataModel.GetModuleDataResponse.self, json)
        #expect(response.totalRecords == 149)
        #expect(response.data.count == 5)

        let module = ScheduleFeedbackDataModel.FeedbackModule(dto: response.data[0])
        #expect(module.id == "42111")
        #expect(module.title == "Feedback Report 3")
        #expect(module.category == "data")
        #expect(module.subtitle == "Feedback · data")
    }
}
