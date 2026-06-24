import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class SettingsViewModel {
    var notificationsEnabled = NotificationService.shared.isEnabled
    var healthKitConnected = false
    var isRestoringPurchases = false
    var revenueCatStatusLabel = PurchaseConfigurationStatus.notConfigured.connectionLabel

    func setNotificationsEnabled(_ enabled: Bool, userId: String?, context: ModelContext) {
        notificationsEnabled = enabled
        NotificationService.shared.isEnabled = enabled

        Task {
            if enabled, let userId {
                _ = await NotificationService.shared.ensureAuthorization()
                await NotificationService.shared.rescheduleAllReminders(
                    userId: userId,
                    context: context
                )
            } else {
                NotificationService.shared.cancelAllPendingReminders()
            }
        }
    }

    func connectHealthKit(appState: AppState) async {
        guard appState.isPro else {
            appState.requireUpgrade(for: .healthKitSync)
            return
        }

        do {
            try await HealthKitService.shared.requestAuthorization(isPro: appState.isPro)
            await refreshHealthKitStatus()
        } catch {
            await refreshHealthKitStatus()
        }
    }

    func refreshHealthKitStatus() async {
        await HealthKitService.shared.syncAuthorizationRequestStatus()
        healthKitConnected = HealthKitService.shared.connectionState() == .connected
    }

    func refreshRevenueCatStatus() {
        let status = PurchaseService.shared.configureIfNeeded()
        revenueCatStatusLabel = status.connectionLabel
    }

    func restorePurchases(appState: AppState) async {
        refreshRevenueCatStatus()
        guard PurchaseService.shared.isConfigured else { return }
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            let info = try await PurchaseService.shared.restorePurchases()
            appState.isPro = info.entitlements[AppConstants.RevenueCat.proEntitlementID]?.isActive == true
            refreshRevenueCatStatus()
        } catch {
            refreshRevenueCatStatus()
            // TODO: Surface error to user
        }
    }

    func signOut(appState: AppState) async {
        NotificationService.shared.resetAllReminders()
        if AppConstants.Backend.useLocalOnly {
            LocalSessionService.clearSession()
        } else {
            try? await SupabaseManager.shared.signOut()
        }
        appState.signOut()
    }

    func deleteAccount(userId: String, appState: AppState, context: ModelContext) async {
        NotificationService.shared.resetAllReminders()
        try? SwiftDataStack.shared.deleteAllData(for: userId, context: context)

        if AppConstants.Backend.useLocalOnly {
            LocalSessionService.clearSession()
        } else {
            try? await SupabaseManager.shared.signOut()
        }

        appState.signOut()
    }
}
