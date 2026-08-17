import Foundation

/// Verbatim `ILTSchedule/GetScheduleDetailsByID` response captured from UAT.
/// Shared by the DTO-decoding, draft-hydration, and update-payload tests.
enum EditScheduleFixtures {

    static let detailsJSON = """
    {
        "id": 3892,
        "scheduleCode": "SC6821",
        "moduleId": 46111,
        "batchId": null,
        "startDate": "2026-08-04T00:00:00",
        "endDate": "2026-08-04T00:00:00",
        "startTime": "19:10",
        "endTime": "19:12",
        "startTimeString": null,
        "endTimeString": null,
        "registrationEndDate": "2026-08-04T00:00:00",
        "isActive": true,
        "isDeleted": false,
        "placeID": 8,
        "trainerType": "Internal",
        "placeName": "Mumbai",
        "moduleName": "19372_Schedule Creation",
        "courseName": "Schedule Creation",
        "categoryName": null,
        "subCategoryName": null,
        "subSubCategoryName": null,
        "courseCode": "19372",
        "courseType": null,
        "academyAgencyID": 28,
        "academyAgencyName": "Mumbai",
        "academyTrainerID": null,
        "trainerList": [
            {
                "academyTrainerID": 8973,
                "academyTrainerName": "kashif",
                "trainerType": "Internal",
                "emailID": null,
                "trainerEmail": "kodV1wwpC1fAiTRuK2jifcKuE9h5S1AXqBAr2D1V05o=",
                "nameUserId": "kashif-kashif (Internal)"
            }
        ],
        "holidayList": [
            {
                "date": "2026-08-04T00:00:00",
                "isHoliday": false,
                "reason": "Work Day"
            }
        ],
        "topicList": [],
        "agencyTrainerName": null,
        "academyTrainerName": null,
        "trainerDescription": null,
        "scheduleType": "Scheduled",
        "reasonForCancellation": null,
        "city": "Mumbai",
        "seatCapacity": "100",
        "contactNumber": null,
        "postalAddress": "J W Marriott Dadar West",
        "contactPersonName": null,
        "placeType": "Internal",
        "courseID": 57812,
        "status": true,
        "eventLogo": null,
        "cost": 0.0,
        "currency": "",
        "webinarType": null,
        "zoomCode": null,
        "batchCode": null,
        "batchName": null,
        "userName": null,
        "userCreated": false,
        "trainerName": null,
        "teamsScheduleDetails": null,
        "zoomScheduleDetails": null,
        "googleMeetDetails": null,
        "purpose": "Planned Training",
        "scheduleCapacity": 100,
        "feedbackId": null,
        "feedbackName": null,
        "createdDate": "03-08-2026 07:11 PM",
        "modifiedDate": "03-08-2026 07:11 PM",
        "createdBy": "LMS Admin",
        "modifiedBy": "LMS Admin",
        "timezone": "India Standard Time",
        "isWebinar": false,
        "webinarAccount": null,
        "tagList": [],
        "record": false,
        "autoStartRecording": false,
        "allowStartStopRecording": false,
        "requestApproval": null
    }
    """
}
