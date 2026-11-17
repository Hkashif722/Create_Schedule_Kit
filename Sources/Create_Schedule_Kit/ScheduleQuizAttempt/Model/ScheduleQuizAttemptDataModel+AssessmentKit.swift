//
//  ScheduleQuizAttemptDataModel+AssessmentKit.swift
//  Create_Schedule_Kit
//
//  Player models in the shapes AssessmentKit draws: option rows, the question palette and the
//  "Q1." header, same as the main app's assessment.
//

import Foundation
import AssessmentKit
import SwiftUIUtilities

extension ScheduleQuizAttemptDataModel {

    typealias Segment = SharesAssessmentBottomSegmentDataModel.SegmentDataInfoModel<Int>

    static func segments(for questions: [PlayerQuestion], sheet: AnswerSheet, visitedIDs: Set<Int>) -> [Segment] {
        questions.enumerated().map { index, question in
            let id = question.attemptQuestionId
            let answered = sheet.isAnswered(id)
            return Segment(
                id: id,
                sequenceNo: index + 1,
                attempted: answered,
                notAttempted: !answered,
                visited: visitedIDs.contains(id)
            )
        }
    }

    static func numberedQuestionText(_ text: String, number: Int) -> AttributedString {
        var prefix = AttributedString("Q\(number). ")
        prefix.inlinePresentationIntent = .stronglyEmphasized
        return prefix + AttributedString(text)
    }

    /// org-content path -> full url, same resolver the main app's assessment uses for contentPath
    static func mediaURL(_ path: String?) -> URL? {
        guard let path = trimmedPath(path) else { return nil }
        return ResourceUtils.getParsedThumbnailPathURL(path)
    }
}

extension ScheduleQuizAttemptDataModel.QuestionMedia {

    /// the AssessmentKit type whose preview draws this media (image / audio / video player)
    var assessmentContentType: AssessmentKit.ContentType {
        switch self {
        case .image: return .imageText
        case .audio: return .textAudio
        case .video: return .textVideo
        }
    }
}

extension ScheduleQuizAttemptDataModel.PlayerQuestion {

    var mediaURL: URL? { media == nil ? nil : ScheduleQuizAttemptDataModel.mediaURL(contentPath) }

    /// how AssessmentKit draws the answers. Only option-pick types exist here (Answer takes
    /// option ids), so it's image cards or the radio / checkbox list, never a text box
    var answerContentType: AssessmentKit.ContentType {
        hasImageOptions ? .image : .objective
    }
}

extension ScheduleQuizAttemptDataModel.ResultQuestion {

    var mediaURL: URL? { media == nil ? nil : ScheduleQuizAttemptDataModel.mediaURL(contentPath) }

    var selectedImageURLs: [URL] { options.filter(\.isSelected).compactMap(\.imageURL) }
    var correctImageURLs: [URL] { options.filter(\.isCorrect).compactMap(\.imageURL) }
}

extension ScheduleQuizAttemptDataModel.ResultOption {
    var imageURL: URL? { ScheduleQuizAttemptDataModel.mediaURL(optionMediaFile) }
}

extension SharedAssessmentOptionModel {

    init(from option: ScheduleQuizAttemptDataModel.PlayerOption, questionID: Int, isSelected: Bool) {
        self.init(
            id: option.stableID,
            title: option.optionText,
            imagePath: ScheduleQuizAttemptDataModel.mediaURL(option.optionMediaFile),
            isSelected: isSelected,
            questionID: questionID,
            optionText: option.optionText,
            selectedOptionId: Int32(clamping: option.id)
        )
    }
}
