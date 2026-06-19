import Foundation
import Observation
import AuthenticationServices
import SwiftUI
import SwiftData

@Observable
@MainActor
final class AuthViewModel {
    var email = ""
    var password = ""
    var isSignUpMode = false
    var authState: AuthState = .unauthenticated
    var errorMessage: String?

    var isLoading: Bool {
        if case .loading = authState { return true }
        return false
    }

    // MARK: - Email

    func signInWithEmail(appState: AppState, context: ModelContext) async {
        guard validateEmailCredentials() else { return }
        await performAuth(appState: appState, context: context) {
            try await SupabaseManager.shared.signInWithEmail(email: email, password: password)
        }
    }

    func signUpWithEmail(appState: AppState, context: ModelContext) async {
        guard validateEmailCredentials() else { return }
        await performAuth(appState: appState, context: context) {
            try await SupabaseManager.shared.signUpWithEmail(email: email, password: password)
            if SupabaseManager.shared.cachedSession == nil {
                throw AuthViewModelError.emailConfirmationRequired
            }
        }
    }

    // MARK: - Apple

    func signInWithApple(
        authorization: ASAuthorization,
        appState: AppState,
        context: ModelContext
    ) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            setError(SupabaseManagerError.invalidAppleCredential.localizedDescription)
            return
        }

        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            setError(SupabaseManagerError.missingIdentityToken.localizedDescription)
            return
        }

        let fullName = credential.fullName?.formatted()

        await performAuth(appState: appState, context: context) {
            try await SupabaseManager.shared.signInWithApple(idToken: idToken, fullName: fullName)
        }
    }

    // MARK: - Google

    func signInWithGoogle(
        webAuthenticationSession: WebAuthenticationSession,
        appState: AppState,
        context: ModelContext
    ) async {
        await performAuth(appState: appState, context: context) {
            try await SupabaseManager.shared.signInWithGoogle { url in
                try await webAuthenticationSession.authenticate(
                    using: url,
                    callbackURLScheme: AppConstants.Auth.oauthCallbackScheme
                )
            }
        }
    }

    // MARK: - Sign Out

    func signOut(appState: AppState) async {
        authState = .loading
        errorMessage = nil

        do {
            if AppConstants.Backend.useLocalOnly {
                LocalSessionService.clearSession()
            } else {
                try await SupabaseManager.shared.signOut()
            }
            appState.signOut()
            authState = .unauthenticated
        } catch {
            setError(error.localizedDescription)
        }
    }

    func continueLocally(appState: AppState, context: ModelContext) {
        authState = .loading
        errorMessage = nil

        let userId = LocalSessionService.ensureUser()
        authState = .authenticated(userId: userId)
        appState.setAuthenticated(userId: userId, context: context)
    }

    func toggleSignUpMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSignUpMode.toggle()
        }
        errorMessage = nil
    }

    // MARK: - Private

    private func performAuth(
        appState: AppState,
        context: ModelContext,
        operation: () async throws -> Void
    ) async {
        authState = .loading
        errorMessage = nil

        do {
            try await operation()

            guard let session = await SupabaseManager.shared.currentSession() else {
                throw AuthViewModelError.sessionUnavailable
            }

            let userId = session.user.id.uuidString
            authState = .authenticated(userId: userId)
            appState.setAuthenticated(userId: userId, context: context)
        } catch AuthViewModelError.emailConfirmationRequired {
            authState = .unauthenticated
            errorMessage = "Check your email to confirm your account."
        } catch {
            setError(error.localizedDescription)
        }
    }

    private func validateEmailCredentials() -> Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            setError("Enter email and password.")
            return false
        }
        return true
    }

    private func setError(_ message: String) {
        authState = .error(message)
        errorMessage = message
    }
}

enum AuthViewModelError: LocalizedError {
    case sessionUnavailable
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            "Unable to retrieve session after sign in."
        case .emailConfirmationRequired:
            "Check your email to confirm your account."
        }
    }
}

private extension PersonNameComponents {
    func formatted() -> String {
        PersonNameComponentsFormatter.localizedString(from: self, style: .default)
    }
}
