//
//  ScheduleQuizContractTests.swift
//  Create_Schedule_KitTests
//
//  Wire contract for the manager-side quiz routes: paths, bodies (explicit nulls) and the
//  response shapes, including the live UAT `GET ILTScheduleQuiz/{id}` body.
//

import Testing
import Foundation
import NetworkService
@testable import Create_Schedule_Kit

@Suite struct ScheduleQuizContractTests {

    typealias DM = ScheduleQuizDataModel

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func object(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Paths

    @Test func quizRoutes() {
        #expect(DM.GetScheduleQuizzesRequest(scheduleID: 482).path == "/api/v1/ILTScheduleQuiz/Schedule/482")
        #expect(DM.CreateQuizRequest(scheduleID: 482).path == "/api/v1/ILTScheduleQuiz/Schedule/482")
        #expect(DM.GetQuizRequest(quizID: 32).path == "/api/v1/ILTScheduleQuiz/32")
        #expect(DM.SaveQuizRequest(quizID: 32).path == "/api/v1/ILTScheduleQuiz/32")
        #expect(DM.PublishQuizRequest(quizID: 32).path == "/api/v1/ILTScheduleQuiz/32/Publish")
        #expect(DM.GetBankQuestionsRequest().path == "/api/v1/ILTScheduleQuiz/GetBankQuestions")
        #expect(DM.InlineQuestionRequest().path == "/api/v1/ILTScheduleQuiz/InlineQuestion")
        #expect(DM.GetPackagesRequest().path == "/api/v1/QuestionPackage/GetPackages")
        #expect(DM.GetPackageRequest(packageID: 12).path == "/api/v1/QuestionPackage/12")
    }

    @Test func methods() {
        #expect(DM.GetScheduleQuizzesRequest(scheduleID: 1).method == .get)
        #expect(DM.CreateQuizRequest(scheduleID: 1).method == .post)
        #expect(DM.SaveQuizRequest(quizID: 1).method == .post)
        #expect(DM.PublishQuizRequest(quizID: 1).method == .post)
        #expect(DM.DeleteQuizRequest(quizID: 1, confirm: false).method == .delete)
        #expect(DM.GetPackagesRequest().method == .post)
        #expect(DM.GetPackageRequest(packageID: 1).method == .get)
    }

    @Test func deleteOnlyCarriesConfirmOnTheSecondCall() {
        #expect(DM.DeleteQuizRequest(quizID: 32, confirm: false).path == "/api/v1/ILTScheduleQuiz/32")
        #expect(DM.DeleteQuizRequest(quizID: 32, confirm: true).path == "/api/v1/ILTScheduleQuiz/32?confirm=true")
    }

    // MARK: - Request bodies

    @Test func createBodySendsExplicitNullsForBlankScoring() throws {
        let settings = QuizDraft.Settings(title: "Fire — pre check", instructions: "",
                                          passPercentage: nil, durationMinutes: nil, showResultToLearner: true)
        let body = try object(settings.createPayload(kind: .post))
        #expect(body["quizTypeId"] as? Int == 2)
        #expect(body["title"] as? String == "Fire — pre check")
        #expect(body["passPercentage"] is NSNull)
        #expect(body["durationMinutes"] is NSNull)
        #expect(body["instructions"] is NSNull)
        #expect(body["showResultToLearner"] as? Bool == true)
    }

    @Test func saveBodyIsTheFullState() throws {
        let payload = DM.SaveQuizPayload(
            title: "Fire safety — Post quiz", instructions: "Answer all questions.",
            passPercentage: 70, durationMinutes: 20, showResultToLearner: true,
            packageIds: [12],
            questions: [.init(assessmentQuestionId: 640, isCreatedInline: true),
                        .init(assessmentQuestionId: 517, isCreatedInline: false)]
        )
        let body = try object(payload)
        #expect(Set(body.keys) == ["title", "instructions", "passPercentage", "durationMinutes",
                                   "showResultToLearner", "packageIds", "questions"])
        #expect(body["packageIds"] as? [Int] == [12])
        let questions = try #require(body["questions"] as? [[String: Any]])
        #expect(questions.first?["assessmentQuestionId"] as? Int == 640)
        #expect(questions.first?["isCreatedInline"] as? Bool == true)
        #expect(questions.last?["isCreatedInline"] as? Bool == false)
    }

    @Test func inlineQuestionBody() throws {
        var form = QuizInlineQuestionDataModel.Form()
        form.questionText = "  Which extinguisher is used on electrical fires? "
        form.marksText = "2"
        form.options = [.init(text: "CO2", isCorrect: true), .init(text: "Water")]
        let body = try object(try #require(form.payload))
        #expect(body["questionText"] as? String == "Which extinguisher is used on electrical fires?")
        #expect(body["optionType"] as? String == "SingleSelection")
        #expect(body["marks"] as? Int == 2)
        #expect(body["difficultyLevel"] as? String == "Simple")
        let options = try #require(body["options"] as? [[String: Any]])
        #expect(options.count == 2)
        #expect(options[0]["optionText"] as? String == "CO2")
        #expect(options[0]["isCorrectAnswer"] as? Bool == true)
    }

    // MARK: - Responses

    /// Verbatim UAT body for schedule 4826's pre quiz (one option trimmed for length).
    static let uatQuizDetail = """
    {"scheduleId":4826,"instructions":"Answer every question before the session starts.",
     "packages":[{"packageId":1,"packageName":"Package1","packageExists":true,"questionCount":2,"totalMarks":2.00,
       "questions":[{"id":658,"assessmentQuestionId":1,"sourceTypeId":1,
         "questionText":"A staff member who suffers from a persistent illness may be:","learnerInstruction":null,
         "optionType":"SingleSelection","questionStyle":null,"section":"objective","difficultyLevel":"Simple",
         "marks":1.00,"mediaFile":null,"contentType":null,"contentPath":null,
         "options":[{"id":1647,"optionText":"Attention-seeking","optionMediaFile":null,"isCorrect":false}]},
        {"id":659,"assessmentQuestionId":2,"sourceTypeId":1,"questionText":"Second","optionType":"MultipleSelection",
         "difficultyLevel":"Tough","marks":1.00,"options":[]}]}],
     "questions":[],"id":97,"quizTypeId":1,"quizType":"PreQuiz","title":"class56 — pre check",
     "totalQuestions":2,"totalMarks":2.00,"passPercentage":null,"durationMinutes":null,
     "showResultToLearner":true,"isPublished":true,"publishedOn":"29-10-2026","isLocked":true,"attemptCount":1}
    """

    @Test func uatQuizDetailDecodes() throws {
        let detail = try decode(DM.QuizDetail.self, Self.uatQuizDetail)
        #expect(detail.summary.id == 97)
        #expect(detail.summary.title == "class56 — pre check")
        #expect(detail.summary.totalMarks == 2)
        #expect(detail.summary.passPercentage == nil)
        #expect(detail.summary.isLocked)
        #expect(detail.summary.attemptCount == 1)
        #expect(detail.scheduleId == 4826)
        #expect(detail.packages.first?.packageName == "Package1")
        #expect(detail.packages.first?.questions.count == 2)
        #expect(detail.questions.isEmpty)
    }

    @Test func scheduleSlotsDecodeWithAnEmptySlot() throws {
        let json = """
        {"scheduleId":482,"preQuiz":{"id":31,"quizTypeId":1,"quizType":"PreQuiz","title":"Fire safety — Pre quiz",
         "totalQuestions":10,"totalMarks":14,"passPercentage":60,"durationMinutes":15,"showResultToLearner":true,
         "isPublished":true,"publishedOn":"16/10/2026","isLocked":false,"attemptCount":0},"postQuiz":null}
        """
        let slots = try decode(DM.ScheduleQuizzes.self, json)
        #expect(slots.quiz(.pre)?.passText == "60%")
        #expect(slots.quiz(.pre)?.durationText == "15 min")
        #expect(slots.quiz(.post) == nil)
    }

    @Test func saveResultDecodesAndIgnoresEnvelopeNoise() throws {
        let json = """
        {"id":32,"totalQuestions":3,"totalMarks":4,"previousTotalMarks":3,"refreshedFromBank":[],
         "removedFromBank":[],"duplicatesSkipped":["dup"],"messages":["dup","Total marks changed from 3 to 4."],
         "error":null,"description":null,"statusCode":200,"isSuccess":true}
        """
        let result = try decode(DM.QuizSaveResult.self, json)
        #expect(result.totalQuestions == 3)
        #expect(result.messages?.count == 2)
    }

    @Test func pickerPagesDecode() throws {
        let bank = try decode(DM.Page<DM.BankQuestion>.self, """
        {"data":[{"id":517,"questionText":"Where is the assembly point?","optionType":"SingleSelection",
          "section":"objective","difficultyLevel":"Simple","marks":1,"optionsCount":4,"alreadyAdded":true}],
         "totalCount":37}
        """)
        #expect(bank.totalCount == 37)
        #expect(bank.data.first?.alreadyAdded == true)

        let packages = try decode(DM.Page<DM.PackageListItem>.self, """
        {"data":[{"id":12,"packageName":"Safety Induction v2","description":"Standard plant safety questions",
          "status":true,"questionCount":20,"unavailableQuestionCount":1,"totalMarks":38,
          "modifiedBy":"Niranjan Shirdhone","modifiedDate":"16/10/2026"}],"totalCount":1}
        """)
        #expect(packages.data.first?.unavailableQuestionCount == 1)

        let empty = try decode(DM.Page<DM.BankQuestion>.self, "{}")
        #expect(empty.data.isEmpty && empty.totalCount == 0)
    }

    @Test func packageDetailDecodes() throws {
        let detail = try decode(DM.PackageDetail.self, """
        {"id":12,"packageName":"Safety Induction v2","description":null,"status":true,"questionCount":1,
         "unavailableQuestionCount":0,"totalMarks":1,"usedByQuizCount":3,"usedByUnlockedQuizCount":1,
         "questions":[{"assessmentQuestionId":501,"sortOrder":1,"questionText":"What colour is the fire exit sign?",
           "learnerInstruction":null,"optionType":"SingleSelection","questionStyle":null,"section":"Fire safety",
           "difficultyLevel":"Simple","marks":1,"mediaFile":null,"contentType":null,"contentPath":null,
           "isAvailable":true,"options":[]}]}
        """)
        #expect(detail.questions.first?.assessmentQuestionId == 501)
    }

    @Test func marksFormatting() {
        #expect(2.0.marksText == "2")
        #expect(2.5.marksText == "2.5")
        #expect(0.0.marksText == "0")
    }

    // MARK: - Errors

    @Test func badRequestKeepsCodeAndDescription() throws {
        let error = APIError.badRequest(
            ["message": "Duplicate", "description": "A package named \"X\" already exists.", "statusCode": 409],
            rawJSON: ""
        )
        let mapped = try #require(AssessmentAPIError(error))
        #expect(mapped.statusCode == 400)
        #expect(mapped.isCode("duplicate"))
        #expect(mapped.message(fallback: "x") == "A package named \"X\" already exists.")
    }

    @Test func conflictKeepsOnlyTheCode() throws {
        let mapped = try #require(AssessmentAPIError(APIError.serverError(statusCode: 409, message: "DependancyExist")))
        #expect(mapped.statusCode == 409)
        #expect(mapped.isCode("DependancyExist"))
        #expect(mapped.message(fallback: "fallback") == "fallback")
    }

    @Test func internalServerErrorNeverShowsItsDescription() throws {
        let error = APIError.badRequest(["message": "InternalServerError", "description": "stack trace"], rawJSON: "")
        #expect(AssessmentAPIError(error)?.message(fallback: "Try again") == "Try again")
    }

    @Test func transportFailuresAreNotAssessmentErrors() {
        #expect(AssessmentAPIError(APIError.noData) == nil)
        #expect(AssessmentAPIError(URLError(.notConnectedToInternet)) == nil)
    }
}
