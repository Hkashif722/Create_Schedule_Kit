//
//  APIConst.swift
//  Create_Schedule_Kit
//
//  Created by Kashif Hussain on 17/06/26.
//

import Foundation

internal struct APIConst {

    static let courseBaseUrl = "/api"
    static let versionAPI = "v1"
    static let lxpPath = "/org-content"
    static nonisolated(unsafe) var baseURL = ""
    static nonisolated(unsafe) var lxpOPath = ""
    static nonisolated(unsafe) var lxpBlobPath = ""
    static nonisolated(unsafe) var lxpBlobPath1 = ""

    // MARK: - ILTSchedule
    /// POST create-schedule (with webinar/meeting). `ILTSchedule/PostWithMeeting`.
    static let iltSchedule = "ILTSchedule"
    static let postWithMeeting = "PostWithMeeting"
    static let getAcademyTypeAhead = "GetAcademyTypeAhead"
    static let internalSegment = "Internal"
    static let getAllTags = "GetAllTags"
    static let scheduleCode = "ScheduleCode"
    static let getScheduleData = "GetScheduleData"
    static let count = "count"
    static let getScheduleDetailsByID = "GetScheduleDetailsByID"
    static let updateILTScheduleWithMeeting = "UpdateILTScheduleWithMeeting"
    static let cancellationSchedule = "CancellationSchedule"
    static let getNominationCountDetails = "GetNominationCountDetails"

    // MARK: - TrainingPlace
    static let trainingPlace = "TrainingPlace"
    static let trainingPlaceTypeAhead = "TrainingPlaceTypeAhead"

    // MARK: - User
    static let userLower = "user"   // lowercase route — do not normalize
    static let user = "User"
    static let searchTrainer = "searchTrainer"
    static let searchActiveInActiveUser = "searchActiveInActiveUser"
    /// Existence check used before creating an external trainer. `User/Exist`.
    static let exist = "Exist"
    static let setting = "Setting"
    static let getColumnsForAccessibilty = "GetColumnsForAccessibilty"
    static let getTypeAhead = "GetTypeAhead"

    // MARK: - TrainingNomination
    static let trainingNomination = "TrainingNomination"
    static let getRoleCourseNameTypeAhead = "GetRoleCourseNameTypeAhead"
    static let getByModuleId = "GetByModuleId"
    static let getUsersCountForNomination = "GetUsersCountForNomination"
    static let getNominateUserCount = "GetNominateUserCount"
    static let getUsersForNominationV2 = "GetUsersForNominationV2"
    static let nominateUser = "NominateUser"
    static let deleteUserNomination = "DeleteUserNomination"

    // MARK: - Module
    static let module = "Module"
    static let moduleLower = "module"   // lowercase route — do not normalize
    static let getModulesILTByCourse = "GetModulesILTByCourse"
    static let getModuleData = "GetModuleData"

    // MARK: - ILTBatch
    static let iSegment = "i"
    static let iltBatch = "ILTBatch"
    static let isBatchwiseNominationEnabled = "IsBatchwiseNominationEnabled"

    // MARK: - ILTTrainingAttendance
    static let iltTrainingAttendance = "ILTTrainingAttendance"
    static let getUsersForAttendance = "GetUsersForAttendance"
    static let getUsersForWaiting = "GetUsersForWaiting"
    static let getUsersCountForAttendance = "GetUsersCountForAttendance"
    static let attendanceDelete = "AttendanceDelete"
    static let getDetailsForUserAttendance = "GetDetailsForUserAttendance"

    // MARK: - ConfigurableParameters
    static let configurableParameters = "ConfigurableParameters"
    static let getValue = "GetValue"

    // MARK: - ConfigurableValues / user parameters
    static let configurableValues = "ConfigurableValues"
    static let attdStatus = "ATTDSTATUS"
    static let getConfigurableParameterValue = "GetConfigurableParameterValue"
    static let attendanceOnCurrentDate = "AttendanceOnCurrentDate"

    // MARK: - Static assets
    static let timezonesJsonPath = "/assets/json_data/timezones.json"
}
