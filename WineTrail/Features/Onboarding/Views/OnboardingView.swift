import SwiftUI

/// Onboarding carousel shown to new users who have no tastings yet.
///
/// Displays a 3-slide intro showing the app's value, then a CTA to log the first wine.
/// Once the sheet is dismissed (tasting saved or cancelled), AppState navigates to the main TabView.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var showLogTasting = false
    @State private var currentPage = 0

    private let slides: [(icon: String, title: String, subtitle: String)] = [
        ("wineglass.fill", "Track Your Wines", "Keep a personal diary of every wine you taste."),
        ("chart.bar.fill", "Discover Patterns", "See your favourites, top regions, and how your palate evolves."),
        ("heart.fill", "Remember Every Sip", "Notes, photos, and ratings — never forget a great bottle.")
    ]

    var body: some View {
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
                    showLogTasting = true
                }
            } label: {
                Text(currentPage < slides.count - 1 ? "Next" : "Add Your First Wine")
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
                    showLogTasting = true
                }
                .font(Theme.captionFont)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            } else {
                Spacer().frame(height: 40)
            }
        }
        .sheet(isPresented: $showLogTasting, onDismiss: {
            NotificationCenter.default.post(name: .tastingDidChange, object: nil)
            appState.currentRoute = .main
        }) {
            LogTastingView()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState(
            authService: AuthService(),
            tastingService: TastingService(apiClient: APIClient(
                serverURL: URL(string: "https://api.winetrail.app")!,
                authService: AuthService()
            ))
        ))
        .environment(WineService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(TastingService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(PhotoService(apiClient: APIClient(
            serverURL: URL(string: "https://api.winetrail.app")!,
            authService: AuthService()
        )))
        .environment(LocationService())
}
