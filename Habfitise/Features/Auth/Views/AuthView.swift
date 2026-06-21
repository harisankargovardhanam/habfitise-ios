import AuthenticationServices
import SwiftUI
import SwiftData

struct AuthView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    @State private var viewModel = AuthViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                theme.colors.headerBackground
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    HabfitiseLogoView(height: 120, maxWidth: 240)
                        .padding(.horizontal, HabfitiseSpacing.xl)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    AuthBottomCard {
                        if AppConstants.Backend.useLocalOnly {
                            localOnlyCard
                        } else {
                            cloudAuthCard
                        }
                    }
                    .frame(minHeight: geometry.size.height * 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            if case let .error(message) = appState.authState {
                viewModel.errorMessage = message
            }
        }
    }

    private var localOnlyCard: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
            localOnlyHeader

            Text("Your workouts, habits, and tasks are saved on this device.")
                .font(HabfitiseTypography.subheadline)
                .foregroundStyle(theme.colors.textSecondary)

            HabfitisePrimaryButton(title: "Get started") {
                viewModel.continueLocally(appState: appState, context: modelContext)
            }
        }
    }

    private var cloudAuthCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                header

                if AppConstants.Capabilities.signInWithApple {
                    AppleSignInButtonView { result in
                        handleAppleSignIn(result)
                    }
                    .disabled(viewModel.isLoading)
                }

                GoogleSignInButton(isEnabled: !viewModel.isLoading) {
                    Task {
                        await viewModel.signInWithGoogle(
                            webAuthenticationSession: webAuthenticationSession,
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
                    isEnabled: !viewModel.isLoading
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

    private var localOnlyHeader: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            HabfitiseLogoView(height: 28)

            Text("Start building your plan")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            HabfitiseLogoView(height: 28)

            Text("Sign in to continue")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
        }
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
                    appState: appState,
                    context: modelContext
                )
            case let .failure(error):
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
