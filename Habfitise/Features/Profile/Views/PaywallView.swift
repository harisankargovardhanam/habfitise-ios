import SwiftUI

struct PaywallView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var settingsViewModel = SettingsViewModel()
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private let features = [
        ("sparkles", "AI Daily Planner"),
        ("heart.fill", "Apple Health Sync"),
        ("infinity", "Unlimited Habits"),
        ("icloud.fill", "Cloud Sync"),
        ("chart.line.uptrend.xyaxis", "Advanced Analytics"),
        ("bell.badge.fill", "Custom Reminders")
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(theme.colors.accentGreen)

                        Text(AppConstants.proProductName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("Unlock your full fitness potential")
                            .font(.system(size: 15))
                            .foregroundStyle(theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            HStack(spacing: 14) {
                                Image(systemName: feature.0)
                                    .font(.system(size: 17))
                                    .foregroundStyle(theme.colors.accentGreen)
                                    .frame(width: 28)

                                Text(feature.1)
                                    .font(.system(size: 15))
                                    .foregroundStyle(theme.colors.textPrimary)

                                Spacer()

                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.colors.accentGreen)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            if index < features.count - 1 {
                                Divider()
                                    .overlay(Color.white.opacity(0.08))
                                    .padding(.leading, 58)
                            }
                        }
                    }
                    .background(theme.colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.colors.danger)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await purchase() }
                    } label: {
                        Text(isPurchasing ? "Processing..." : "Upgrade to Pro")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(theme.colors.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isPurchasing || settingsViewModel.isRestoringPurchases)

                    Button {
                        Task { await settingsViewModel.restorePurchases(appState: appState) }
                    } label: {
                        Text(settingsViewModel.isRestoringPurchases ? "Restoring..." : "Restore Purchases")
                            .font(.system(size: 15))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    .disabled(settingsViewModel.isRestoringPurchases || isPurchasing)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(AppConstants.proProductName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .toolbarBackground(theme.colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private func purchase() async {
        guard PurchaseService.shared.isConfigured else {
            errorMessage = PurchaseServiceError.notConfigured(PurchaseService.shared.configurationStatus.issue).errorDescription
            return
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let offerings = try await PurchaseService.shared.fetchOfferings()
            guard let package = offerings.current?.availablePackages.first else {
                errorMessage = "No subscription packages available."
                return
            }
            let info = try await PurchaseService.shared.purchase(package: package)
            appState.isPro = info.entitlements[AppConstants.RevenueCat.proEntitlementID]?.isActive == true
            if appState.isPro {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
