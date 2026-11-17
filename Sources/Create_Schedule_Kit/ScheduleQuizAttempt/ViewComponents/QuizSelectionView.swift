//
//  QuizSelectionView.swift
//  Create_Schedule_Kit
//
//  Answer area of a quiz question, routed through AssessmentKit like the main app's assessment:
//  image cards when every option is a picture, else the radio (single) / checkbox (multiple) list.
//

import SwiftUI
import AssessmentKit

struct QuizSelectionView: View {

    let questionID: Int
    /// `.image` = picture cards, `.objective` = text list. See `PlayerQuestion.answerContentType`
    var contentType: AssessmentKit.ContentType = .objective
    let options: [SharedAssessmentOptionModel]
    let optionType: AssessmentKit.OptionType
    let onSelect: (SharedAssessmentOptionModel) -> Void

    var body: some View {
        SharedAssessmentSelectionTypeView(
            questionID: questionID,
            contentType: contentType,
            options: options,
            optionType: optionType,
            isSelected: { $0.isSelected },
            handleSelection: onSelect,
            getTitle: { $0.optionText ?? $0.title },
            handleImageSelection: onSelect
        )
    }
}

#Preview {
    QuizSelectionView(
        questionID: 901,
        options: [
            SharedAssessmentOptionModel(title: "Paris", isSelected: true, questionID: 901, optionText: "Paris", selectedOptionId: 11),
            SharedAssessmentOptionModel(title: "Lyon", questionID: 901, optionText: "Lyon", selectedOptionId: 12),
            SharedAssessmentOptionModel(title: "Nice", questionID: 901, optionText: "Nice", selectedOptionId: 13)
        ],
        optionType: .singleSelection,
        onSelect: { _ in }
    )
    .padding()
}
