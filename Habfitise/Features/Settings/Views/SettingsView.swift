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

                        HStack {
                            Text("Apple Health")
                            Spacer()
                            Text(viewModel.healthKitConnected ? "Connected" : "Not connected")
                                .foregroundStyle(viewModel.healthKitConnected ? theme.colors.accentGreen : theme.colors.textSecondary)
                        }

                        HStack(alignment: .top) {
                            Text("RevenueCat")
                            Spacer()
                            Text(viewModel.revenueCatStatusLabel)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(
                                    PurchaseService.shared.isConfigured
                                        ? theme.colors.accentGreen
                                        : theme.colors.textSecondary
                                )
                        }

                        Button(viewModel.healthKitConnected ? "Manage in Settings" : "Connect Apple Health") {
                            if viewModel.healthKitConnected {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } else {
                                Task { await viewModel.connectHealthKit(appState: appState) }
                            }
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
        .task {
            viewModel.refreshRevenueCatStatus()
            await viewModel.refreshHealthKitStatus()
            if let userId = appState.authenticatedUserId {
                _ = await PurchaseService.shared.bootstrapSubscription(for: userId)
                viewModel.refreshRevenueCatStatus()
            }
        }
    }
}
