import Foundation
import Supabase
import AuthenticationServices

@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    private(set) var client: SupabaseClient?
    private(set) var cachedSession: Session?

    var isConfigured: Bool {
        client != nil
    }

    var currentUser: User? {
        cachedSession?.user
    }

    private init() {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: AppConstants.Supabase.urlKey) as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: AppConstants.Supabase.anonKeyKey) as? String,
            !urlString.isEmpty,
            !anonKey.isEmpty,
            !urlString.contains("your-project"),
            !anonKey.contains("your-anon-key"),
            let url = URL(string: urlString)
        else {
            client = nil
            return
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    redirectToURL: AppConstants.Auth.oauthRedirectURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        Task { await refreshSession() }
    }

    // MARK: - Session

    func refreshSession() async {
        guard let client else {
            cachedSession = nil
            return
        }
        cachedSession = try? await client.auth.session
    }

    func currentSession() async -> Session? {
        guard let client else { return nil }
        let session = try? await client.auth.session
        cachedSession = session
        return session
    }

    // MARK: - Auth State Stream

    var authStateStream: AsyncStream<AuthState> {
        AsyncStream { continuation in
            guard let client else {
                continuation.yield(.error(SupabaseManagerError.notConfigured.localizedDescription))
                continuation.finish()
                return
            }

            let task = Task {
                continuation.yield(.loading)

                for await (event, session) in client.auth.authStateChanges {
                    cachedSession = session

                    switch event {
                    case .initialSession:
                        if let session {
                            continuation.yield(.authenticated(userId: session.user.id.uuidString))
                        } else {
                            continuation.yield(.unauthenticated)
                        }
                    case .signedIn, .tokenRefreshed:
                        if let session {
                            continuation.yield(.authenticated(userId: session.user.id.uuidString))
                        }
                    case .signedOut:
                        cachedSession = nil
                        continuation.yield(.unauthenticated)
                    case .userUpdated, .userDeleted, .passwordRecovery, .mfaChallengeVerified:
                        if let session {
                            continuation.yield(.authenticated(userId: session.user.id.uuidString))
                        } else {
                            continuation.yield(.unauthenticated)
                        }
                    @unknown default:
                        break
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Email

    func signInWithEmail(email: String, password: String) async throws {
        guard let client else { throw SupabaseManagerError.notConfigured }
        let session = try await client.auth.signIn(email: email, password: password)
        cachedSession = session
    }

    func signUpWithEmail(email: String, password: String) async throws {
        guard let client else { throw SupabaseManagerError.notConfigured }
        let response = try await client.auth.signUp(email: email, password: password)
        cachedSession = response.session
    }

    // MARK: - Apple

    func signInWithApple(idToken: String, fullName: String?, nonce: String?) async throws {
        guard let client else { throw SupabaseManagerError.notConfigured }

        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        cachedSession = session

        if let fullName, !fullName.isEmpty {
            _ = try? await client.auth.update(
                user: UserAttributes(data: ["full_name": .string(fullName)])
            )
        }
    }

    // MARK: - Google (OAuth)

    func signInWithGoogle() async throws {
        guard let client else { throw SupabaseManagerError.notConfigured }

        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: AppConstants.Auth.oauthRedirectURL
        )
        cachedSession = session
    }

    // MARK: - Sign Out

    func signOut() async throws {
        guard let client else { throw SupabaseManagerError.notConfigured }
        try await client.auth.signOut()
        cachedSession = nil
    }

    func handleDeepLink(_ url: URL) async throws {
        guard let client else { throw SupabaseManagerError.notConfigured }
        let session = try await client.auth.session(from: url)
        cachedSession = session
    }
}

enum SupabaseManagerError: LocalizedError {
    case notConfigured
    case missingIdentityToken
    case invalidAppleCredential

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to Config/Secrets.xcconfig."
        case .missingIdentityToken:
            "Apple Sign In did not return a valid identity token."
        case .invalidAppleCredential:
            "Apple Sign In returned an invalid credential."
        }
    }
}
