//
//  QuizInlineQuestionDataModel.swift
//  Create_Schedule_Kit
//
//  Form + validation for "Write a new question". The rules are the server's, checked here
//  first so a bad form never round-trips: text ≤ 1500, marks 1–25, 2–5 options with none
//  empty and no duplicate text, at least one correct (exactly one for single selection).
//  Text only — no media in this form.
//

import Foundation

enum QuizInlineQuestionDataModel {

    static let textLimit = 1500
    static let instructionLimit = 200
    static let marksRange: ClosedRange<Int> = 1...25
    static let optionCountRange: ClosedRange<Int> = 2...5

    struct OptionRow: Identifiable, Equatable {
        let id: UUID
        var text: String
        var isCorrect: Bool

        init(id: UUID = UUID(), text: String = "", isCorrect: Bool = false) {
            self.id = id
            self.text = text
            self.isCorrect = isCorrect
        }

        var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    struct Form: Equatable {
        var questionText = ""
        var optionType: ScheduleQuizDataModel.OptionType = .single
        var marksText = "1"
        var difficulty: ScheduleQuizDataModel.Difficulty = .simple
        var learnerInstruction = ""
        var options: [OptionRow] = (0..<4).map { _ in OptionRow() }
    }
}

// MARK: - Editing

extension QuizInlineQuestionDataModel.Form {

    typealias DM = QuizInlineQuestionDataModel

    var canAddOption: Bool { options.count < DM.optionCountRange.upperBound }
    var canRemoveOption: Bool { options.count > DM.optionCountRange.lowerBound }

    mutating func addOption() {
        guard canAddOption else { return }
        options.append(DM.OptionRow())
    }

    mutating func removeOption(id: UUID) {
        guard canRemoveOption else { return }
        options.removeAll { $0.id == id }
    }

    /// Single selection behaves like a radio group; multiple toggles independently.
    mutating func toggleCorrect(id: UUID) {
        guard let index = options.firstIndex(where: { $0.id == id }) else { return }
        switch optionType {
        case .single:
            for i in options.indices { options[i].isCorrect = (i == index) }
        case .multiple:
            options[index].isCorrect.toggle()
        }
    }

    /// Going back to single keeps only the first ticked answer.
    mutating func setOptionType(_ type: ScheduleQuizDataModel.OptionType) {
        optionType = type
        guard type == .single else { return }
        var kept = false
        for i in options.indices where options[i].isCorrect {
            if kept { options[i].isCorrect = false } else { kept = true }
        }
    }

    static func optionLetter(at index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E"]
        return letters.indices.contains(index) ? letters[index] : "\(index + 1)"
    }
}

// MARK: - Validation

extension QuizInlineQuestionDataModel.Form {

    private var trimmedText: String { questionText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedInstruction: String { learnerInstruction.trimmingCharacters(in: .whitespacesAndNewlines) }

    var marks: Int? {
        Int(marksText.trimmingCharacters(in: .whitespaces))
    }

    var validationMessage: String? {
        if trimmedText.isEmpty { return "Enter the question." }
        if trimmedText.utf16.count > DM.textLimit { return "The question can be at most \(DM.textLimit) characters." }
        guard let marks, DM.marksRange.contains(marks) else { return "Marks must be a whole number from 1 to 25." }
        if trimmedInstruction.utf16.count > DM.instructionLimit {
            return "Learner instruction can be at most \(DM.instructionLimit) characters."
        }
        guard DM.optionCountRange.contains(options.count) else { return "Add 2 to 5 options." }
        if options.contains(where: { $0.trimmedText.isEmpty }) { return "Fill in or remove the empty option." }
        let lowered = options.map { $0.trimmedText.lowercased() }
        if Set(lowered).count != lowered.count { return "Two options have the same text." }
        let correctCount = options.filter(\.isCorrect).count
        if correctCount == 0 { return "Mark the correct answer." }
        if optionType == .single, correctCount > 1 { return "Single selection takes exactly one correct answer." }
        return nil
    }

    var payload: ScheduleQuizDataModel.InlineQuestionPayload? {
        guard validationMessage == nil, let marks else { return nil }
        return .init(
            questionText: trimmedText,
            optionType: optionType.rawValue,
            marks: marks,
            difficultyLevel: difficulty.rawValue,
            learnerInstruction: trimmedInstruction.isEmpty ? nil : trimmedInstruction,
            options: options.map { .init(optionText: $0.trimmedText, isCorrectAnswer: $0.isCorrect) }
        )
    }

    /// What the editor lists once the bank has the question.
    func question(id: Int) -> QuizDraft.Question {
        QuizDraft.Question(
            assessmentQuestionId: id,
            text: trimmedText,
            optionType: optionType,
            difficulty: difficulty.rawValue,
            marks: Double(marks ?? 0),
            source: .createdInline
        )
    }
}
