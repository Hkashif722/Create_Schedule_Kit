//
//  ScheduleFeedbackView.swift
//  Create_Schedule_Kit
//
//  Step 3 — Feedback. Optional: attach feedback module(s) to the schedule.
//

import SwiftUI
import SwiftfulRouting
import SwiftUIUtilities

struct ScheduleFeedbackView: View {

    @StateObject private var viewModel: ScheduleFeedbackViewModel
    private let router: AnyRouter

    private let teal = Color.teal

    private let isEditMode: Bool

    init(router: AnyRouter,
         draft: ScheduleDraft,
         isEditMode: Bool = false,
         onBack: @escaping () -> Void,
         onContinue: @escaping () -> Void,
         onSkipCreate: @escaping () -> Void) {
        self.router = router
        self.isEditMode = isEditMode
        _viewModel = StateObject(
            wrappedValue: ScheduleFeedbackViewModel(
                router: router, draft: draft,
                onBack: onBack, onContinue: onContinue, onSkipCreate: onSkipCreate
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    feedbackCard
                    skipButton
                }
                .padding()
            }
            footer
        }
        .toastViewPkg(toast: $viewModel.toast)
    }

    private var feedbackCard: some View {
        CSSectionCard(
            icon: "bubble.left",
            iconColor: teal,
            title: "Feedback details",
            subtitle: "Post-session feedback form",
            isOptional: true
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Attach a feedback module learners complete after the schedule. Skip this if your organization doesn't collect schedule-level feedback.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let module = viewModel.selectedModule {
                    selectedModuleView(module)
                } else {
                    emptyState
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(teal.opacity(0.12))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "bubble.left").font(.system(size: 22, weight: .semibold)).foregroundColor(teal))
            Text("No feedback module yet")
                .font(.system(size: 16, weight: .bold))
            Text("Add one, or continue without — this step is optional.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            CSPrimaryButton(title: "Choose feedback module", systemImage: "plus") {
                viewModel.openPicker()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func selectedModuleView(_ module: ScheduleFeedbackDataModel.FeedbackModule) -> some View {
        VStack(spacing: 10) {
            moduleRow(module)
            Button { viewModel.openPicker() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Change feedback module")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorUtility.primaryColor)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private func moduleRow(_ module: ScheduleFeedbackDataModel.FeedbackModule) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(teal.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "bubble.left").font(.system(size: 15, weight: .semibold)).foregroundColor(teal))
            VStack(alignment: .leading, spacing: 2) {
                Text(module.title).font(.system(size: 15, weight: .bold))
                Text(module.subtitle).font(.system(size: 12.5)).foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            Button { viewModel.clearSelection() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var skipButton: some View {
        Button { viewModel.didTapSkipCreate() } label: {
            HStack(spacing: 8) {
                Image(systemName: "forward.end")
                Text(isEditMode ? "Skip & update schedule" : "Skip & create schedule")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        CSNavFooter(
            nextTitle: isEditMode ? "Update Schedule" : "Create Schedule",
            nextSystemImage: nil,
            onBack: { viewModel.didTapBack() },
            onNext: { viewModel.didTapContinue() }
        )
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @Environment(\.router) var router
    SwiftUtilityEnvironment.configure(
        SwiftUtilityConfig(
            encryptionDecryptionKey: "preview-key",
            isBlobEnabled: true,
            orgCode: "preview",
            configurableDate: "dd-MM-yyyy",
            baseURL: "",
            lxpOPath: "",
            lxpBlobPath: "",
            lxpBlobPath1: ""
        )
    )
    return ScheduleFeedbackView(router: router, draft: ScheduleDraft(),
                                onBack: {}, onContinue: {}, onSkipCreate: {})
}
