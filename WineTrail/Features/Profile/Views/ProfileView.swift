import SwiftUI
import FirebaseAuth

/// Profile screen showing user account information and sign-out action.
///
/// Displays the user's avatar, display name (editable), email, account creation date,
/// and a sign-out button. Changes to the display name are persisted via the API.
struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(ProfileService.self) private var profileService
    @Environment(AppState.self) private var appState

    @State private var displayName: String = ""
    @State private var isEditingName = false
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                userInfoHeader
            }

            Section {
                if isEditingName {
                    HStack {
                        TextField("Display name", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Display name")
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Save") {
                                Task { await saveDisplayName() }
                            }
                            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                } else {
                    HStack {
                        LabeledContent("Display Name", value: authService.currentUser?.displayName ?? "Not set")
                        Spacer()
                        Button {
                            displayName = authService.currentUser?.displayName ?? ""
                            isEditingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.wineAccent)
                        }
                        .accessibilityLabel("Edit display name")
                    }
                }

                if let email = authService.currentUser?.email {
                    LabeledContent("Email", value: email)
                }
                if let creationDate = authService.currentUser?.metadata.creationDate {
                    LabeledContent("Member since", value: creationDate.formatted(.dateTime.month(.wide).year()))
                }
                if let lastSignIn = authService.currentUser?.metadata.lastSignInDate {
                    LabeledContent("Last sign in", value: lastSignIn.formatted(.dateTime.month(.abbreviated).day().year()))
                }
            }

            if let error {
                Section {
                    Text(error)
                        .font(Theme.captionFont)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    try? authService.signOut()
                    appState.currentRoute = .auth
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Profile")
    }

    // MARK: - User Info Header

    @ViewBuilder
    private var userInfoHeader: some View {
        HStack(spacing: Theme.spacing) {
            avatar
            VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                Text(authService.currentUser?.displayName ?? "Wine Enthusiast")
                    .font(Theme.headlineFont)
                    .foregroundStyle(.wineText)
                if let email = authService.currentUser?.email {
                    Text(email)
                        .font(Theme.captionFont)
                        .foregroundStyle(.wineSecondaryText)
                }
            }
        }
        .padding(.vertical, Theme.smallSpacing)
    }

    @ViewBuilder
    private var avatar: some View {
        if let photoURL = authService.currentUser?.photoURL {
            AsyncImage(url: photoURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)
            .foregroundStyle(.wineAccent)
    }

    // MARK: - Actions

    private func saveDisplayName() async {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        error = nil
        do {
            try await profileService.updateDisplayName(trimmed)
            // Update Firebase Auth profile to keep local state in sync
            let changeRequest = authService.currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = trimmed
            try await changeRequest?.commitChanges()
            isEditingName = false
        } catch {
            Log.error("Failed to update profile", error: error)
            self.error = "Something went wrong. Please try again."
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthService())
            .environment(ProfileService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            )))
    }
}
