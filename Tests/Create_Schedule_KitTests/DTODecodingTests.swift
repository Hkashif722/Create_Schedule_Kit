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
