import SwiftUI

/// Email/password sign-in and account creation form.
///
/// Uses `AuthViewModel` to coordinate sign-in so that post-sign-in
/// side effects (FCM registration, route determination) fire automatically.
struct EmailSignInView: View {
    @Environment(AuthService.self) private var authService
    @Environment(DeviceService.self) private var deviceService
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AuthViewModel?
    @State private var email = ""
    @State private var password = ""
    @State private var isCreateAccount = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textContentType(isCreateAccount ? .newPassword : .password)
                }

                if let error = viewModel?.error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(Theme.captionFont)
                    }
                }

                Section {
                    Button(isCreateAccount ? "Create Account" : "Sign In") {
                        submit()
                    }
                    .disabled(email.isEmpty || password.isEmpty || viewModel?.isLoading == true)
                    .frame(maxWidth: .infinity)
                }

                Section {
                    Button(isCreateAccount ? "Already have an account? Sign In" : "Don't have an account? Create one") {
                        isCreateAccount.toggle()
                        viewModel?.dismissError()
                    }
                    .font(Theme.captionFont)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(isCreateAccount ? "Create Account" : "Email Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if viewModel?.isLoading == true {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = AuthViewModel(
                        authService: authService,
                        deviceService: deviceService,
                        appState: appState
                    )
                }
            }
        }
    }

    private func submit() {
        guard let vm = viewModel else { return }
        Task {
            if isCreateAccount {
                await vm.createAccount(email: email, password: password)
            } else {
                await vm.signInWithEmail(email: email, password: password)
            }
            // If sign-in succeeded (no error), dismiss the sheet
            if vm.error == nil {
                dismiss()
            }
        }
    }
}
