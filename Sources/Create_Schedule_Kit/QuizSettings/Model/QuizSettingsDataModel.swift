//
//  QuizSettingsDataModel.swift
//  Create_Schedule_Kit
//
//  Form state + validation for the quiz settings sheet ("Create pre quiz" and the editor's
//  Edit). Limits mirror the API: title ≤ 250, pass 0–100 or blank (no pass/fail), duration
//  1–1440 whole minutes or blank (untimed).
//

import Foundation

enum QuizSettingsDataModel {

    static let titleLimit = 250
    static let passRange: ClosedRange<Double> = 0...100
    static let durationRange: ClosedRange<Int> = 1...1440

    enum Mode: Equatable {
        /// Creates the quiz on the server, then hands back its id.
        case create(scheduleID: Int)
        /// Hands the edited settings back to the editor; nothing is saved until the editor's Save.
        case edit
    }

    enum Outcome {
        case created(quizID: Int)
        case applied(QuizDraft.Settings)
        /// Create hit 409: the slot already has a quiz on the server (made elsewhere, or by an
        /// earlier create whose response never arrived). The spec says reload and open it.
        case alreadyExists
    }

    struct Form: Equatable {
        var title: String
        var instructions: String
        var passText: String
        var durationText: String
        var showResultToLearner: Bool
    }
}

// MARK: - Form

extension QuizSettingsDataModel.Form {

    init(settings: QuizDraft.Settings) {
        self.init(
            title: settings.title,
            instructions: settings.instructions,
            passText: settings.passPercentage?.marksText ?? "",
            durationText: settings.durationMinutes.map(String.init) ?? "",
            showResultToLearner: settings.showResultToLearner
        )
    }

    /// Seeds a new quiz the way the web does: "<module> — pre check".
    static func defaults(kind: ScheduleQuizDataModel.QuizKind, displayName: String) -> Self {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = kind == .pre ? "pre check" : "post check"
        return Self(
            title: name.isEmpty ? kind.slotTitle : "\(name) — \(suffix)",
            instructions: kind == .pre
                ? "Answer every question before the session starts."
                : "Answer every question. You have one attempt.",
            passText: "",
            durationText: "",
            showResultToLearner: true
        )
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPass: String { passText.trimmingCharacters(in: .whitespaces) }
    private var trimmedDuration: String { durationText.trimmingCharacters(in: .whitespaces) }

    /// Blank → nil. Accepts "60", "60.5" and "60,5".
    var passPercentage: Double? {
        guard !trimmedPass.isEmpty else { return nil }
        return Double(trimmedPass.replacingOccurrences(of: ",", with: "."))
    }

    var durationMinutes: Int? {
        trimmedDuration.isEmpty ? nil : Int(trimmedDuration)
    }

    /// First rule the form breaks, worded for a toast. Nil when it can be submitted.
    var validationMessage: String? {
        typealias DM = QuizSettingsDataModel
        if trimmedTitle.isEmpty { return "Enter a quiz title." }
        if trimmedTitle.utf16.count > DM.titleLimit { return "Title can be at most \(DM.titleLimit) characters." }
        if !trimmedPass.isEmpty {
            guard let pass = passPercentage, DM.passRange.contains(pass) else {
                return "Pass percentage must be 0–100, or blank for no pass/fail."
            }
        }
        if !trimmedDuration.isEmpty {
            guard let minutes = durationMinutes, DM.durationRange.contains(minutes) else {
                return "Duration must be 1–1440 whole minutes, or blank for untimed."
            }
        }
        return nil
    }

    var settings: QuizDraft.Settings? {
        guard validationMessage == nil else { return nil }
        return QuizDraft.Settings(
            title: trimmedTitle,
            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
            passPercentage: passPercentage,
            durationMinutes: durationMinutes,
            showResultToLearner: showResultToLearner
        )
    }
}

// MARK: - Payload

extension QuizDraft.Settings {

    func createPayload(kind: ScheduleQuizDataModel.QuizKind) -> ScheduleQuizDataModel.CreateQuizPayload {
        .init(
            quizTypeId: kind.rawValue,
            title: title,
            instructions: instructions.isEmpty ? nil : instructions,
            passPercentage: passPercentage,
            durationMinutes: durationMinutes,
            showResultToLearner: showResultToLearner
        )
    }
}
