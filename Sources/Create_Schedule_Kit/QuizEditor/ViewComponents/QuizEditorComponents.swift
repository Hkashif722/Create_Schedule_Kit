//
//  QuizEditorComponents.swift
//  Create_Schedule_Kit
//
//  Building blocks of the quiz editor: settings summary, the three add-question tiles, package
//  cards, direct question rows, and the "add the other quiz?" popup body.
//

import SwiftUI
import SwiftUIUtilities

// MARK: - Settings summary

struct QuizSettingsSummaryCard: View {
    let settings: QuizDraft.Settings
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Quiz settings")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(CSTheme.primaryColor)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit quiz settings")
            }
            HStack(alignment: .top) {
                stat("Pass", settings.passPercentage.map { "\($0.marksText)%" } ?? "—")
                stat("Duration", settings.durationMinutes.map { "\($0) min" } ?? "Untimed")
                stat("Result shown", settings.showResultToLearner ? "Yes" : "No")
            }
            Divider()
            Text("Once a learner attempts this quiz it locks: questions, pass % and duration become read-only. Title, instructions and result visibility stay editable.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13)).foregroundColor(.secondary)
            Text(value).font(.system(size: 17, weight: .bold)).foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Add-question tile

struct QuizSourceTile: View {
    let title: String
    let systemImage: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(isEnabled ? .primary : .secondary)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.systemBackground)))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Package card

struct QuizPackageCardView: View {
    let package: QuizDraft.Package
    let startIndex: Int
    let isExpanded: Bool
    let canRemove: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                Divider()
                questions
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        CSStatusChip(title: "PACKAGE", tint: Color(red: 0.23, green: 0.25, blue: 0.66))
                        Text(package.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    if !package.exists {
                        Label("Package no longer exists", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    Text("\(package.questionCount.questionsLabel) · \(package.totalMarks.marksLabel) · read-only here, edit the package to change them")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses the questions" : "Shows the questions")

            Button(action: onToggle) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove package \(package.name)")
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var questions: some View {
        if package.isPreviewFailed {
            Text("Couldn't load this package's questions. They're still included when you save.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
        } else if !package.isPreviewLoaded {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading questions…").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .padding(14)
        } else if package.questions.isEmpty {
            Text("No available questions in this package.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(14)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(package.questions.enumerated()), id: \.element.id) { offset, question in
                    QuizQuestionRowView(index: startIndex + offset + 1, question: question,
                                        showsSource: false, onRemove: nil)
                    if offset < package.questions.count - 1 { Divider().padding(.leading, 52) }
                }
            }
        }
    }
}

// MARK: - Direct questions

struct QuizDirectQuestionsCard: View {
    let questions: [QuizDraft.Question]
    let startIndex: Int
    let canRemove: Bool
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Added directly")
                    .font(.system(size: 17, weight: .bold))
                Text("Picked from the bank or written here, served after package questions")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            Divider()
            ForEach(Array(questions.enumerated()), id: \.element.id) { offset, question in
                QuizQuestionRowView(
                    index: startIndex + offset + 1,
                    question: question,
                    showsSource: true,
                    onRemove: canRemove ? { onRemove(question.id) } : nil
                )
                if offset < questions.count - 1 { Divider().padding(.leading, 52) }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

struct QuizQuestionRowView: View {
    let index: Int
    let question: QuizDraft.Question
    let showsSource: Bool
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(red: 0.55, green: 0.36, blue: 0.0))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(red: 1.0, green: 0.85, blue: 0.40).opacity(0.7)))
                .accessibilityLabel("Question \(index)")

            VStack(alignment: .leading, spacing: 6) {
                Text(question.text.isEmpty ? "Untitled question" : question.text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if showsSource {
                        CSStatusChip(title: question.source.chipTitle, tint: .secondary)
                    }
                    Text(question.metaText)
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(question.marksText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize()
            if let onRemove {
                SwiftUIUtility.CircleCloseButton(
                    foregroundColor: .secondary,
                    backgroundColor: .clear,
                    size: 36,
                    action: onRemove
                )
                .accessibilityLabel("Remove question \(index)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - "Add the other quiz?" popup body

struct QuizAddOtherPromptContent: View {
    let kind: ScheduleQuizDataModel.QuizKind
    let questionCount: Int

    var body: some View {
        VStack(spacing: 14) {
            Text("\(questionCount) \(questionCount == 1 ? "question" : "questions") added to the \(kind.slotTitle).")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 10) {
                CSQuizKindBadge(kind: kind.other)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add \(kind.other.slotTitle)?")
                        .font(.system(size: 15, weight: .bold))
                    Text(kind.other == .post
                         ? "Would you like to set up a Post-Schedule Quiz for after the session as well?"
                         : "Would you like to set up a Pre-Schedule Quiz for before the session as well?")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(kind.other.badgeBackground.opacity(0.25))
            )
        }
        .padding()
    }
}

#Preview {
    let question = QuizDraft.Question(
        assessmentQuestionId: 517, text: "Where is the assembly point?", optionType: .single,
        difficulty: "Simple", marks: 1, source: .pickedFromBank
    )
    return ScrollView {
        VStack(spacing: 14) {
            QuizSettingsSummaryCard(
                settings: .init(title: "Fire safety", instructions: "", passPercentage: 60,
                                durationMinutes: 10, showResultToLearner: true),
                onEdit: {}
            )
            HStack(spacing: 10) {
                QuizSourceTile(title: "Add package", systemImage: "archivebox", action: {})
                QuizSourceTile(title: "From bank", systemImage: "list.bullet.rectangle", action: {})
                QuizSourceTile(title: "Write new", systemImage: "pencil", isEnabled: false, action: {})
            }
            QuizPackageCardView(
                package: .init(id: 12, name: "mark", exists: true, questionCount: 1, totalMarks: 1,
                               questions: [question], isPreviewLoaded: true),
                startIndex: 0, isExpanded: true, canRemove: true, onToggle: {}, onRemove: {}
            )
            QuizDirectQuestionsCard(questions: [question], startIndex: 1, canRemove: true, onRemove: { _ in })
            QuizAddOtherPromptContent(kind: .pre, questionCount: 3)
        }
        .padding()
    }
    .background(Color.scheduleBackground)
}
