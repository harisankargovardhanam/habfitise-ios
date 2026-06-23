import AuthenticationServices
import SwiftUI
import SwiftData

struct AuthView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = AuthViewModel()
    @State private var appleSignInNonce: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                theme.colors.background
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    HabfitiseLogoView(height: 56, maxWidth: 220)
                        .padding(.horizontal, HabfitiseSpacing.xl)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    AuthBottomCard {
                        cloudAuthCard
                    }
                    .frame(minHeight: geometry.size.height * 0.5)
                }
                .ignoresSafeArea(edges: .bottom)

                if viewModel.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(theme.colors.accentGreen)
                }
            }
        }
        .onAppear {
            if case let .error(message) = appState.authState {
                viewModel.errorMessage = message
            }
        }
    }

    private var cloudAuthCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                header

                if !viewModel.isSupabaseConfigured {
                    supabaseSetupBanner
                }

                if AppConstants.Capabilities.signInWithApple {
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = AuthNonce.random()
                        appleSignInNonce = nonce
                        request.requestedScopes = [.email, .fullName]
                        request.nonce = AuthNonce.sha256(nonce)
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: HabfitiseRadius.lg))
                    .disabled(viewModel.isLoading || !viewModel.isSupabaseConfigured)
                }

                GoogleSignInButton(
                    isEnabled: !viewModel.isLoading && viewModel.isSupabaseConfigured
                ) {
                    Task {
                        await viewModel.signInWithGoogle(
                            appState: appState,
                            context: modelContext
                        )
                    }
                }

                AuthOrDivider()

                emailFields

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(HabfitiseTypography.caption)
                        .foregroundStyle(theme.colors.danger)
                }

                HabfitisePrimaryButton(
                    title: viewModel.isSignUpMode ? "Create account" : "Sign in",
                    isEnabled: !viewModel.isLoading && viewModel.isSupabaseConfigured
                ) {
                    Task { await submitEmailAuth() }
                }

                Button {
                    viewModel.toggleSignUpMode()
                } label: {
                    Text(
                        viewModel.isSignUpMode
                            ? "Already have an account? Sign in"
                            : "Need an account? Create account"
                    )
                    .font(HabfitiseTypography.subheadline)
                    .foregroundStyle(theme.colors.accentGreen)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(HabfitiseScalePressButtonStyle())
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("Sign in to continue")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var supabaseSetupBanner: some View {
        Text("Add SUPABASE_URL and SUPABASE_ANON_KEY to Config/Secrets.xcconfig to enable sign in.")
            .font(HabfitiseTypography.caption)
            .foregroundStyle(theme.colors.danger)
            .padding(HabfitiseSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HabfitiseRadius.md)
                    .fill(theme.colors.fieldBackground)
            )
    }

    private var emailFields: some View {
        VStack(spacing: HabfitiseSpacing.md) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .habfitiseAuthTextFieldStyle()

            SecureField("Password", text: $viewModel.password)
                .textContentType(viewModel.isSignUpMode ? .newPassword : .password)
                .habfitiseAuthTextFieldStyle()
        }
    }

    private func submitEmailAuth() async {
        if viewModel.isSignUpMode {
            await viewModel.signUpWithEmail(appState: appState, context: modelContext)
        } else {
            await viewModel.signInWithEmail(appState: appState, context: modelContext)
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            switch result {
            case let .success(authorization):
                await viewModel.signInWithApple(
                    authorization: authorization,
                    rawNonce: appleSignInNonce,
                    appState: appState,
                    context: modelContext
                )
                appleSignInNonce = nil
            case let .failure(error):
                appleSignInNonce = nil
                if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#if DEBUG
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environment(AppState())
            .environment(ThemeManager())
    }
}
#endif
