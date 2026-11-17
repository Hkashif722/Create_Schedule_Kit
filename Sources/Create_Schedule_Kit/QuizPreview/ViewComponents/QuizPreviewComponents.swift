//
//  QuizPreviewComponents.swift
//  Create_Schedule_Kit
//
//  Quiz preview pieces: the settings card, one question section card, and a question with its
//  options (right answer in green).
//

import SwiftUI

// MARK: - Settings card

struct QuizPreviewSummaryCard: View {
    let title: String
    let isPublished: Bool
    let instructions: String?
    let stats: [QuizPreviewDataModel.Stat]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .topLeading), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(title.isEmpty ? "Untitled quiz" : title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                CSStatusChip(title: isPublished ? "Published" : "Draft", tint: isPublished ? .green : .orange)
            }
            if let instructions {
                Text(instructions)
                    .font(.system(size: 13.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(stats) { stat in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stat.title)
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                        Text(stat.value)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Section card

struct QuizPreviewSectionCard: View {
    let section: QuizPreviewDataModel.Section

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .accessibilityAddTraits(.isHeader)
            Divider()
            ForEach(section.questions) { question in
                QuizPreviewQuestionView(question: question)
                if question.id != section.questions.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Question

struct QuizPreviewQuestionView: View {
    let question: QuizPreviewDataModel.Question

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CSQuestionNumberBadge(number: question.number, size: 24)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(question.text.isEmpty ? "Untitled question" : question.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(question.marks.marksLabel)
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
                if !question.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(question.tags, id: \.self) { tag in
                            CSStatusChip(title: tag, tint: .secondary)
                        }
                    }
                }
                if question.options.isEmpty {
                    Text("Options unavailable")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(question.options) { option in
                            QuizPreviewOptionRow(option: option)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

struct QuizPreviewOptionRow: View {
    let option: QuizPreviewDataModel.Option

    private var correctTint: Color { Color(red: 0.24, green: 0.55, blue: 0.18) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: option.isCorrect ? "checkmark" : "xmark")
                .font(.system(size: 12, weight: option.isCorrect ? .bold : .regular))
                .foregroundColor(option.isCorrect ? correctTint : Color(.tertiaryLabel))
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(option.text.isEmpty ? "—" : option.text)
                .font(.system(size: 14, weight: option.isCorrect ? .medium : .regular))
                .foregroundColor(option.isCorrect ? correctTint : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(option.isCorrect ? Color.green.opacity(0.14) : Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue(option.isCorrect ? "Correct answer" : "")
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            QuizPreviewSummaryCard(
                title: "VILT TTT — pre check",
                isPublished: true,
                instructions: "Answer every question before the session starts.",
                stats: [
                    .init(title: "Pass %", value: "50%"), .init(title: "Duration", value: "10 min"),
                    .init(title: "Result shown", value: "Yes"), .init(title: "Questions", value: "2"),
                    .init(title: "Total marks", value: "2"), .init(title: "Attempts", value: "1")
                ]
            )
            QuizPreviewSectionCard(section: .init(id: "direct", title: "Added Directly", questions: [
                .init(id: 1, number: 1, text: "Favourite pet", marks: 1, tags: ["Simple", "Single"], options: [
                    .init(id: 0, text: "Cat", isCorrect: true), .init(id: 1, text: "Dog", isCorrect: false)
                ]),
                .init(id: 2, number: 2, text: "Square root of 4", marks: 1, tags: ["Simple", "Single"], options: [
                    .init(id: 0, text: "2", isCorrect: true), .init(id: 1, text: "4", isCorrect: false),
                    .init(id: 2, text: "8", isCorrect: false)
                ])
            ]))
        }
        .padding()
    }
    .background(Color.scheduleBackground)
}
