import SwiftUI

/// A view modifier that displays a generic error alert.
/// Bind to an optional error message string — when non-nil, shows the alert.
struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
    }
}

extension View {
    /// Attaches a generic error alert to this view.
    /// When `errorMessage` is non-nil, shows an alert with the message and an OK button.
    func errorAlert(_ errorMessage: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(errorMessage: errorMessage))
    }
}
