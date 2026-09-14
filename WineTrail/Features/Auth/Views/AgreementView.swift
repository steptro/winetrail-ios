import SwiftUI

/// End User License Agreement (EULA) / Terms of Use gate shown before a user can
/// register or log in.
///
/// Presents the agreement, with an explicit, prominent statement that there is
/// **zero tolerance** for objectionable content and abusive behavior, and the
/// tools available to users (report and block). The user must tap
/// "Agree & Continue" to proceed — this satisfies App Store Guideline 1.2's
/// requirement that users agree to such terms before using UGC features.
struct AgreementView: View {
    @Environment(AppState.self) private var appState
    @Environment(AgreementStore.self) private var agreementStore

    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.largeSpacing) {
                    header

                    policyPoint(
                        icon: "hand.raised.fill",
                        tint: .red,
                        title: "Zero tolerance for objectionable content",
                        message: "There is no tolerance for objectionable, abusive, harassing, hateful, or otherwise offensive content or behavior. Content that violates these terms is removed and the responsible accounts are terminated."
                    )

                    policyPoint(
                        icon: "flag.fill",
                        tint: .wineAccent,
                        title: "Report anything objectionable",
                        message: "You can flag any post or comment for review. Our team reviews reports and acts within 24 hours by removing offending content and ejecting offending users."
                    )

                    policyPoint(
                        icon: "nosign",
                        tint: .primary,
                        title: "Block abusive users",
                        message: "You can block any user at any time. Blocking immediately removes their content from your feed and prevents further contact."
                    )

                    legalLinks
                }
                .padding(Theme.spacing)
            }

            agreeBar
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.smallSpacing) {
            Image(systemName: "wineglass.fill")
                .font(.system(size: 52))
                .foregroundStyle(.wineAccent)

            Text("Welcome to WineTrail")
                .font(Theme.titleFont)
                .multilineTextAlignment(.center)

            Text("Before you continue, please review and accept our Terms of Use and community rules.")
                .font(Theme.subheadlineFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.spacing)
    }

    // MARK: - Policy point

    private func policyPoint(icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: Theme.spacing) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Legal links

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Button {
                showTerms = true
            } label: {
                Label("Read the full Terms of Use (EULA)", systemImage: "doc.text")
                    .font(.footnote.weight(.medium))
            }
            Button {
                showPrivacy = true
            } label: {
                Label("Read the Privacy Policy", systemImage: "lock.doc")
                    .font(.footnote.weight(.medium))
            }
        }
        .tint(.wineAccent)
        .padding(.top, Theme.smallSpacing)
        .sheet(isPresented: $showTerms) {
            SafariView(url: AppConfig.termsOfServiceURL)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: AppConfig.privacyPolicyURL)
                .ignoresSafeArea()
        }
    }

    // MARK: - Agree bar

    private var agreeBar: some View {
        VStack(spacing: Theme.smallSpacing) {
            Divider()
            Text("By tapping “Agree & Continue” you accept the Terms of Use and agree to the zero-tolerance policy above.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.spacing)

            Button {
                agree()
            } label: {
                Text("Agree & Continue")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(.wineAccent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.spacing)
            .padding(.bottom, Theme.smallSpacing)
            .accessibilityIdentifier("agreeAndContinueButton")
        }
        .background(.bar)
    }

    private func agree() {
        agreementStore.accept()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { await appState.determineInitialRoute() }
    }
}

#Preview {
    AgreementView()
        .environment(AppState(
            authService: AuthService(),
            journalService: JournalService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )),
            profileService: ProfileService(apiClient: APIClient(
                serverURL: AppConfig.serverURL,
                authService: AuthService()
            )),
            agreementStore: AgreementStore()
        ))
        .environment(AgreementStore())
}
