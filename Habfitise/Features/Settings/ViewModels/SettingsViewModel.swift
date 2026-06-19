import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class SettingsViewModel {
    var notificationsEnabled = true
    var healthKitConnected = false
    var isRestoringPurchases = false

    func connectHealthKit(appState: AppState) async {
        guard appState.isPro else {
            appState.requireUpgrade(for: .healthKitSync)
            return
        }

        do {
            try await HealthKitService.shared.requestAuthorization(isPro: appState.isPro)
            healthKitConnected = true
        } catch {
            healthKitConnected = false
        }
    }

    func restorePurchases(appState: AppState) async {
        guard PurchaseService.shared.isConfigured else { return }
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            let info = try await PurchaseService.shared.restorePurchases()
            appState.isPro = info.entitlements[AppConstants.RevenueCat.proEntitlementID]?.isActive == true
        } catch {
            // TODO: Surface error to user
        }
    }

    func signOut(appState: AppState) async {
        if AppConstants.Backend.useLocalOnly {
            LocalSessionService.clearSession()
        } else {
            try? await SupabaseManager.shared.signOut()
        }
        appState.signOut()
    }

    func deleteAccount(userId: String, appState: AppState, context: ModelContext) async {
        try? SwiftDataStack.shared.deleteAllData(for: userId, context: context)

        if AppConstants.Backend.useLocalOnly {
            LocalSessionService.clearSession()
        } else {
            try? await SupabaseManager.shared.signOut()
        }

        appState.signOut()
    }
}
