//
//  QuizBottomControlView.swift
//  Create_Schedule_Kit
//
//  Bottom of the quiz player: AssessmentKit's question palette, back / forward and Submit,
//  same as the main app's assessment.
//

import SwiftUI
import AssessmentKit

struct QuizBottomControlView: View {

    let currentIndex: Int
    let totalQuestions: Int
    let isFirstQuestion: Bool
    let showsSubmit: Bool
    let isSubmitEnabled: Bool
    let segments: [ScheduleQuizAttemptDataModel.Segment]
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSelectQuestion: (Int) -> Void
    let onSubmit: () -> Void

    var body: some View {
        // kit only shows submit on "last" q. time-up / closed answers need it on any q, hence showsSubmit
        SharedAssessmentBottomControlView<Int>(
            currentQuestionIndex: currentIndex,
            totalQuestions: totalQuestions,
            isFirstQuestion: isFirstQuestion,
            isLastQuestion: showsSubmit,
            submitButtonText: "Submit Quiz",
            isSubmitButtonEnabled: isSubmitEnabled,
            bottomSegmentDataModel: segments,
            goToPreviousQuestion: onPrevious,
            goToNextQuestion: onNext,
            jumpToQuestion: onSelectQuestion,
            submitAssessment: onSubmit
        )
    }
}

#Preview {
    QuizBottomControlView(
        currentIndex: 2,
        totalQuestions: 5,
        isFirstQuestion: false,
        showsSubmit: false,
        isSubmitEnabled: true,
        segments: [
            .init(id: 1, sequenceNo: 1, attempted: true, notAttempted: false),
            .init(id: 2, sequenceNo: 2, visited: true),
            .init(id: 3, sequenceNo: 3),
            .init(id: 4, sequenceNo: 4),
            .init(id: 5, sequenceNo: 5)
        ],
        onPrevious: {},
        onNext: {},
        onSelectQuestion: { _ in },
        onSubmit: {}
    )
    .padding()
}
