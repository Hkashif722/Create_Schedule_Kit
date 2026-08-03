//
//  ScheduleFeedbackDataModel.swift
//  Create_Schedule_Kit
//
//  Endpoints + DTOs + domain types for Step 3 (Feedback). Feedback modules are fetched
//  server-side (paginated, filtered to courseType "Feedback") from `GetModuleData`.
//

import Foundation
import NetworkService

enum ScheduleFeedbackDataModel {

    // MARK: - Endpoints

    /// POST paginated module search. Feedback modules are selected with
    /// `search = "Feedback"` + `columnName = "coursetype"`; `searchString` carries the
    /// user-typed keyword (nil/empty returns all). Unlike most endpoints, the response is a
    /// wrapper object (`GetModuleDataResponse`), not a bare array.
    struct GetModuleDataRequest: EndpointModel {
        var path: String {
            [APIConst.courseBaseUrl, APIConst.versionAPI, APIConst.moduleLower, APIConst.getModuleData]
                .joined(separator: "/")
        }
        var method: HTTPMethod { .post }
        var headers: [String: String]? { nil }

        struct Payload: Encodable {
            let page: Int
            let pageSize: Int
            let search: String           // fixed filter value, "Feedback"
            let searchString: String?    // user-typed text (nil/empty = all)
            let columnName: String       // "coursetype"
            let showAllData: Bool        // true
        }
    }

    // MARK: - DTO types

    struct GetModuleDataResponse: Decodable {
        let data: [ModuleDTO]
        let totalRecords: Int
    }

    struct ModuleDTO: Decodable {
        let id: Int
        let name: String
        let description: String?
        let moduleType: String?
        let courseType: String?
        let isActive: Bool?
        let lcmsId: Int?
    }

    // MARK: - Domain types

    struct FeedbackModule: Identifiable, Equatable, Hashable {
        let id: String
        let title: String
        /// Optional category shown as "Feedback · <category>".
        let category: String?

        var subtitle: String {
            if let category, !category.isEmpty { return "Feedback · \(category)" }
            return "Feedback"
        }
    }
}

extension ScheduleFeedbackDataModel.FeedbackModule {

    /// Map a raw `GetModuleData` row to the domain model. `id` is the top-level module id;
    /// the subtitle category is taken from `description`.
    init(dto: ScheduleFeedbackDataModel.ModuleDTO) {
        self.init(id: String(dto.id), title: dto.name, category: dto.description)
    }
}

#if DEBUG
extension ScheduleFeedbackDataModel.FeedbackModule {

    /// Preview-only sample data. Live data comes from `GetModuleData`.
    static let stub: [ScheduleFeedbackDataModel.FeedbackModule] = [
        .init(id: "feedback0906", title: "feedback0906", category: "data"),
        .init(id: "myFeedback", title: "My feedback", category: "test"),
        .init(id: "commSkills", title: "Communication Skills Feedback", category: "Communication skills"),
        .init(id: "testFeedback123", title: "testfeedback123", category: nil),
        .init(id: "configTest", title: "Config Test", category: "Test"),
        .init(id: "postSession", title: "Post-session Survey", category: "NPS + comments"),
        .init(id: "trainerRating", title: "Trainer Rating", category: "5-star rating"),
        .init(id: "quickPulse", title: "Quick Pulse", category: "1-question")
    ]
}
#endif
