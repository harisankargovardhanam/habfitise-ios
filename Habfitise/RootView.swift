import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        rootContent
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appState.authState)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appState.needsOnboarding)
            .sheet(item: upgradeBinding) { trigger in
                UpgradeSheetView(trigger: trigger) {
                    appState.clearPendingNavigation()
                }
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch appState.authState {
        case .loading:
            loadingView

        case .unauthenticated, .error:
            if AppConstants.Backend.useLocalOnly {
                OnboardingView()
            } else {
                AuthView()
            }

        case .authenticated:
            if appState.needsOnboarding {
                OnboardingView(skipWelcome: true)
            } else {
                MainTabView()
            }
        }
    }

    private var loadingView: some View {
        LaunchSplashView()
    }

    private var upgradeBinding: Binding<UpgradeTrigger?> {
        Binding(
            get: {
                if case let .upgrade(trigger) = appState.pendingNavigation {
                    return trigger
                }
                return nil
            },
            set: { newValue in
                if newValue == nil {
                    appState.clearPendingNavigation()
                }
            }
        )
    }
}

private struct UpgradeSheetView: View {
    @Environment(ThemeManager.self) private var themeManager

    let trigger: UpgradeTrigger
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: HabfitiseSpacing.xxl) {
                Text(trigger.title)
                    .font(HabfitiseTypography.title2)
                Text(trigger.message)
                    .font(HabfitiseTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(themeManager.colors.textSecondary)

                HabfitisePrimaryButton(title: "Upgrade to Pro") {
                    onDismiss()
                }

                Button("Not now") { onDismiss() }
                    .foregroundStyle(themeManager.colors.textSecondary)
            }
            .padding(HabfitiseSpacing.xxl)
            .navigationTitle(AppConstants.proProductName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
