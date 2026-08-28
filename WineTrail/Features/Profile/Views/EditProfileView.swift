import SwiftUI
import FirebaseAuth

/// Sub-screen for editing display name and username.
/// Pushed from the redesigned Profile tab's "Edit Profile" row.
struct EditProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ProfileService.self) private var profileService
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var isLoading = true

    var body: some View {
        Form {
            Section {
                TextField("Display Name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            } header: {
                Text("Display Name")
            } footer: {
                Text("This is how you appear to other users.")
            }

            Section {
                HStack {
                    Text("@")
                        .foregroundStyle(.secondary)
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Username")
            } footer: {
                Text("Must be at least 3 characters. Lowercase letters, numbers, and underscores only.")
            }

            if let error {
                Section {
                    Text(error)
                        .font(Theme.captionFont)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await loadCurrent()
        }
    }

    private var canSave: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        return !trimmedName.isEmpty && trimmedUsername.count >= 3
    }

    private func loadCurrent() async {
        displayName = authService.currentUser?.displayName ?? ""
        do {
            let profile = try await profileService.getProfile()
            username = profile.username
        } catch {
            // Use empty — user can set it
        }
        isLoading = false
    }

    private func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()

        guard !trimmedName.isEmpty, trimmedUsername.count >= 3 else { return }

        isSaving = true
        error = nil

        do {
            // Update backend profile (name + username)
            _ = try await profileService.updateProfile(
                displayName: trimmedName,
                username: trimmedUsername
            )

            // Update Firebase Auth display name to keep local state in sync
            let changeRequest = authService.currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = trimmedName
            try await changeRequest?.commitChanges()

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            Log.error("Failed to update profile", error: error)
            self.error = "Username may be taken, or something went wrong. Try again."
        }

        isSaving = false
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environment(AuthService())
            .environment(ProfileService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}
