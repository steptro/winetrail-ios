import SwiftUI

/// Onboarding carousel shown to new users who have no tastings yet.
///
/// Displays a 3-slide intro showing the app's value, then a CTA to log the first wine.
/// Once the sheet is dismissed (tasting saved or cancelled), AppState navigates to the main TabView.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProfileService.self) private var profileService
    @Environment(SocialService.self) private var socialService
    @State private var currentPage = 0
    @State private var showUsernameSetup = false
    @State private var displayName = ""
    @State private var username = ""
    @State private var isSaving = false
    @State private var usernameError: String?
    @State private var usernameAvailable: Bool?
    @State private var isCheckingUsername = false
    @State private var usernameCheckTask: Task<Void, Never>?

    private let slides: [(icon: String, title: String, subtitle: String)] = [
        ("wineglass.fill", "Track Your Wines", "Keep a personal diary of every wine you taste."),
        ("chart.bar.fill", "Discover Patterns", "See your favourites, top regions, and how your palate evolves."),
        ("heart.fill", "Remember Every Sip", "Notes, photos, and ratings — never forget a great bottle.")
    ]

    var body: some View {
        if showUsernameSetup {
            usernameSetupView
        } else {
            carouselView
        }
    }

    // MARK: - Carousel

    @ViewBuilder
    private var carouselView: some View {
        VStack(spacing: 0) {
            // Carousel
            TabView(selection: $currentPage) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    VStack(spacing: Theme.largeSpacing) {
                        Spacer()

                        Image(systemName: slide.icon)
                            .font(.system(size: 70))
                            .foregroundStyle(.wineAccent)
                            .accessibilityHidden(true)

                        Text(slide.title)
                            .font(.title.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(slide.subtitle)
                            .font(Theme.subheadlineFont)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.wineAccent : Color.wineAccent.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 24)

            // CTA Button
            Button {
                if currentPage < slides.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    withAnimation { showUsernameSetup = true }
                }
            } label: {
                Text(currentPage < slides.count - 1 ? "Next" : "Get Started")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(.wineAccent, in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Skip button (visible on first two slides)
            if currentPage < slides.count - 1 {
                Button("Skip") {
                    withAnimation { showUsernameSetup = true }
                }
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            } else {
                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Username Setup

    @ViewBuilder
    private var usernameSetupView: some View {
        VStack(spacing: Theme.largeSpacing) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.wineAccent)

            Text("Set Up Your Profile")
                .font(.title2.weight(.bold))

            Text("Tell us your name and pick a username.")
                .font(Theme.subheadlineFont)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                // Display name field
                TextField("Your name", text: $displayName)
                    .font(.title3)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)

                // Username field
                HStack {
                    Text("@")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    TextField("username", text: $username)
                        .font(.title3)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: username) { _, newValue in
                            checkUsernameAvailability(newValue)
                        }

                    if isCheckingUsername {
                        ProgressView()
                            .controlSize(.small)
                    } else if let available = usernameAvailable {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(available ? .green : .red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)

                if let usernameError {
                    Text(usernameError)
                        .font(Theme.captionFont)
                        .foregroundStyle(.red)
                } else if usernameAvailable == true {
                    Text("Username is available!")
                        .font(Theme.captionFont)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Button {
                Task { await saveUsername() }
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    Text("Continue")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .foregroundStyle(.white)
            .background(.wineAccent, in: Capsule())
            .padding(.horizontal, 24)
            .disabled(username.trimmingCharacters(in: .whitespaces).count < 3 || isSaving)

            Button("Skip for now") {
                appState.currentRoute = .main
            }
            .font(Theme.captionFont)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Username Validation

    private func checkUsernameAvailability(_ value: String) {
        usernameCheckTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()

        // Reset state for short usernames
        if trimmed.count < 3 {
            usernameAvailable = nil
            usernameError = trimmed.isEmpty ? nil : "Username must be at least 3 characters."
            isCheckingUsername = false
            return
        }

        // Validate characters
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            usernameAvailable = false
            usernameError = "Only letters, numbers, dots, underscores, and dashes."
            return
        }

        usernameError = nil
        isCheckingUsername = true

        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            do {
                let results = try await socialService.searchUsers(query: trimmed)
                guard !Task.isCancelled else { return }
                let taken = results.contains { $0.username.lowercased() == trimmed }
                usernameAvailable = !taken
                if taken {
                    usernameError = "Username is already taken."
                }
            } catch {
                guard !Task.isCancelled else { return }
                usernameAvailable = nil
            }
            isCheckingUsername = false
        }
    }

    // MARK: - Save Username

    private func saveUsername() async {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 3 else {
            usernameError = "Username must be at least 3 characters."
            return
        }
        isSaving = true
        usernameError = nil

        do {
            let name = displayName.trimmingCharacters(in: .whitespaces)
            _ = try await profileService.updateProfile(
                displayName: name.isEmpty ? trimmed : name,
                username: trimmed
            )
            WineAnalytics.logOnboardingCompleted(username: trimmed)
            appState.currentRoute = .main
        } catch {
            Log.error("Failed to set username", error: error)
            usernameError = "Username may be taken. Try another."
        }

        isSaving = false
    }
}

#Preview {
    OnboardingView()
        .environment(AppState(
            authService: AuthService(),
            journalService: JournalService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )),
            profileService: ProfileService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            ))
        ))
        .environment(ProfileService(apiClient: APIClient(
            serverURL: AppConfig.serverURL,
            authService: AuthService()
        )))
        .environment(LocationService())
}
