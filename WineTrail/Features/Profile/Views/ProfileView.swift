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
    @Environment(SocialService.self) private var socialService
    @Environment(DeviceService.self) private var deviceService
    @Environment(APIClient.self) private var apiClient

    @State private var displayName: String = ""
    @State private var isEditingName = false
    @State private var isEditingUsername = false
    @State private var editedUsername: String = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var friendCount: Int = 0
    @State private var username: String = ""
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeleting = false

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
                    if isEditingUsername {
                        HStack {
                            Text("@")
                                .foregroundStyle(.secondary)
                            TextField("username", text: $editedUsername)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button {
                                    Task { await saveUsername() }
                                } label: {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.wineAccent)
                                }
                                .disabled(editedUsername.trimmingCharacters(in: .whitespaces).count < 3)

                                Button {
                                    isEditingUsername = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if !username.isEmpty {
                        HStack {
                            LabeledContent("Username", value: "@\(username)")
                            Spacer()
                            Button {
                                editedUsername = username
                                isEditingUsername = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.wineAccent)
                            }
                            .accessibilityLabel("Edit username")
                        }
                    }
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
                NavigationLink {
                    FriendsView()
                } label: {
                    HStack {
                        Label("Friends", systemImage: "person.2")
                        Spacer()
                        Text("\(friendCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        try? await deviceService.unregisterToken()
                        try? authService.signOut()
                        appState.currentRoute = .auth
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    if isDeleting {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Deleting...")
                        }
                    } else {
                        Label("Delete Account", systemImage: "trash")
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("This will permanently delete your account and all your data. This action cannot be undone.")
            }
        }
        .navigationTitle("Profile")
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete My Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, all your wines, tastings, photos, and social data. This cannot be undone.")
        }
        .task {
            await loadFriendCount()
        }
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

    private func loadFriendCount() async {
        do {
            let friends = try await socialService.getFriends()
            friendCount = friends.count
        } catch {
            // Non-critical
        }
        do {
            let profile = try await profileService.getProfile()
            username = profile.username
        } catch {
            // Non-critical
        }
    }

    private func saveUsername() async {
        let trimmed = editedUsername.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 3 else { return }
        isSaving = true
        error = nil

        do {
            let profile = try await profileService.updateProfile(
                displayName: authService.currentUser?.displayName ?? "",
                username: trimmed
            )
            username = profile.username
            isEditingUsername = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            Log.error("Failed to update username", error: error)
            self.error = "Username may be taken. Try another."
        }

        isSaving = false
    }

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

    private func deleteAccount() async {
        isDeleting = true
        do {
            try await deviceService.unregisterToken()
            try await authService.deleteAccount {
                _ = try await apiClient.client.deleteAccount()
            }
            appState.currentRoute = .auth
        } catch {
            Log.error("Failed to delete account", error: error)
            self.error = "Failed to delete account. Please try again."
        }
        isDeleting = false
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
