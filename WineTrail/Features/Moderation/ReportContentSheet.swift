import SwiftUI

/// A sheet that lets the user file a report against objectionable content or an
/// abusive user. Presented from any UGC surface (feed post, tasting detail, comment,
/// profile). On submit it calls `ModerationService.report` and confirms to the user.
struct ReportContentSheet: View {
    @Environment(ModerationService.self) private var moderationService
    @Environment(\.dismiss) private var dismiss

    let target: ReportTarget
    /// Called after a successful submission (e.g. to show a toast).
    var onReported: (() -> Void)?

    @State private var selectedReason: ReportReason = .harassment
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Reports are confidential. Our team reviews reported content and acts within 24 hours by removing violating content and removing offending users.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Reason") {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.label).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Additional details (optional)") {
                    TextField("Describe the problem", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") { Task { await submit() } }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await moderationService.report(target: target, reason: selectedReason, details: details)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onReported?()
            dismiss()
        } catch {
            Log.error("Failed to submit report", error: error)
            errorMessage = "Couldn't submit the report. Please try again."
        }
        isSubmitting = false
    }
}

#Preview {
    ReportContentSheet(target: ReportTarget(
        contentType: .comment,
        contentId: "preview-id",
        authorUserId: "user-id",
        authorName: "someuser"
    ))
    .environment(ModerationService(
        apiClient: APIClient(serverURL: AppConfig.serverURL, authService: AuthService()),
        blockStore: BlockStore()
    ))
}
