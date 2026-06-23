import SwiftUI

struct SettingsView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                Text("Settings")
                    .font(HabfitiseTypography.title2)
                    .foregroundStyle(theme.colors.textOnBackground)

                HabfitiseCard {
                    VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                        Toggle("Notifications", isOn: Binding(
                            get: { viewModel.notificationsEnabled },
                            set: { viewModel.setNotificationsEnabled($0, userId: appState.authenticatedUserId, context: modelContext) }
                        ))

                        HStack {
                            Text(AppConstants.proProductName)
                            Spacer()
                            Text(appState.isPro ? "Active" : "Free")
                                .foregroundStyle(appState.isPro ? theme.colors.accentGreen : theme.colors.textSecondary)
                        }

                        Button("Connect Apple Health") {
                            Task { await viewModel.connectHealthKit(appState: appState) }
                        }
                        .foregroundStyle(theme.colors.accentGreen)

                        Button(viewModel.isRestoringPurchases ? "Restoring..." : "Restore Purchases") {
                            Task { await viewModel.restorePurchases(appState: appState) }
                        }
                        .disabled(viewModel.isRestoringPurchases)

                        Button("Sign Out", role: .destructive) {
                            Task { await viewModel.signOut(appState: appState) }
                        }
                    }
                    .font(HabfitiseTypography.body)
                }
            }
            .padding(.horizontal, HabfitiseSpacing.xxl)
            .padding(.top, HabfitiseSpacing.xxl)
            .padding(.bottom, 100)
        }
    }
}
