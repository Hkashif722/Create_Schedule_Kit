//
//  QuizSelectionView.swift
//  Create_Schedule_Kit
//
//  Answer area of a quiz question: AssessmentKit's option list, same as the main app's
//  assessment. Radio for single choice, checkbox for multiple.
//

import SwiftUI
import AssessmentKit

struct QuizSelectionView: View {

    let questionID: Int
    let options: [SharedAssessmentOptionModel]
    let optionType: AssessmentKit.OptionType
    let onSelect: (SharedAssessmentOptionModel) -> Void

    var body: some View {
        SharedAssessmentSelectionTypeView(
            questionID: questionID,
            contentType: .objective,
            options: options,
            optionType: optionType,
            isSelected: { $0.isSelected },
            handleSelection: onSelect,
            getTitle: { $0.optionText ?? $0.title }
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
