import SwiftUI
import FirebaseAuth

/// Settings screen — account, legal, and account-danger actions. Reached from the gear icon in
/// the Profile navbar (previously this was the "Settings" tab's content).
struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppState.self) private var appState
    @Environment(DeviceService.self) private var deviceService
    @Environment(APIClient.self) private var apiClient
#if DEBUG
    @Environment(AgreementStore.self) private var agreementStore
#endif

    @State private var showDeleteAccountConfirmation = false
    @State private var isDeleting = false
    @State private var error: String?

    var body: some View {
        List {
            // Account
            Section {
                NavigationLink {
                    EditProfileView()
                } label: {
                    Label("Edit Profile", systemImage: "person.fill")
                }
            } header: {
                Text("Account")
            }

            // Legal
            Section {
                NavigationLink {
                    SafariView(url: AppConfig.privacyPolicyURL)
                        .ignoresSafeArea()
                        .navigationTitle("Privacy Policy")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }

                NavigationLink {
                    SafariView(url: AppConfig.termsOfServiceURL)
                        .ignoresSafeArea()
                        .navigationTitle("Terms of Service")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                }
            } header: {
                Text("Legal")
            }

            // Danger
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
            } header: {
                Text("Danger")
            } footer: {
                Text("Permanently deletes your account and all data. This cannot be undone.")
            }

#if DEBUG
            // Developer — debug builds only
            Section {
                Button(role: .destructive) {
                    agreementStore.reset()
                    appState.currentRoute = .agreement
                } label: {
                    Label("Reset EULA Acceptance", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("Clears terms acceptance and returns to the agreement gate. Debug builds only.")
            }
#endif

            // App metadata
            Section {
                appVersionFooter
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Delete Account",
            isPresented: $showDeleteAccountConfirmation
        ) {
            Button("Delete My Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, all your wines, tastings, photos, and social data. This cannot be undone.")
        }
    }

    private var appVersionFooter: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"

        return Text("WineTrail v\(version) (\(build))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .accessibilityLabel("WineTrail version \(version), build \(build)")
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
        SettingsView()
            .environment(AuthService())
            .environment(DeviceService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )))
    }
}
