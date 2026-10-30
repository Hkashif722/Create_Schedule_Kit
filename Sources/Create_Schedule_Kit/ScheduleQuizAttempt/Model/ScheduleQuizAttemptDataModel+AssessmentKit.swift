//
//  ScheduleQuizAttemptDataModel+AssessmentKit.swift
//  Create_Schedule_Kit
//
//  Player models in the shapes AssessmentKit draws: option rows, the question palette and the
//  "Q1." header, same as the main app's assessment.
//

import Foundation
import AssessmentKit

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
}

extension SharedAssessmentOptionModel {

    init(from option: ScheduleQuizAttemptDataModel.PlayerOption, questionID: Int, isSelected: Bool) {
        self.init(
            id: option.stableID,
            title: option.optionText,
            isSelected: isSelected,
            questionID: questionID,
            optionText: option.optionText,
            selectedOptionId: Int32(clamping: option.id)
        )
    }
}
