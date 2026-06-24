import Foundation
import Observation
import SwiftData
import RevenueCat

@Observable
@MainActor
final class AppState {
    var authState: AuthState = .loading
    var needsOnboarding = false
    var isPro = false
    var isRestoringFromCloud = false
    var pendingNavigation: PendingNavigation = .none
    var pendingDeepLinkTab: MainTab?
    var pendingWorkoutBuilder: PendingWorkoutBuilder?

    /// Cloud sync + cross-device restore — Pro only.
    var canUseCloudSync: Bool {
        !AppConstants.Backend.useLocalOnly && isPro
    }

    func applyDebugProOverride() {
        if UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.debugForcePro) {
            isPro = true
        }
    }

    func setDebugProEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: AppConstants.UserDefaultsKeys.debugForcePro)
        isPro = enabled
    }

    func openDeepLinkTab(_ tab: MainTab) {
        pendingDeepLinkTab = tab
    }

    func clearPendingDeepLinkTab() {
        pendingDeepLinkTab = nil
    }

    func refreshWidgets(context: ModelContext) {
        guard let userId = authenticatedUserId else { return }
        WidgetDataPublisher.refresh(context: context, userId: userId)
    }

    /// Restores subscription + remote account state before routing (reinstall-safe).
    func handleAuthenticatedSession(userId: String, context: ModelContext) async {
        let normalizedUserId = Self.normalizeUserId(userId)
        let wasAlreadyAuthenticated = authenticatedUserId == normalizedUserId

        if AppConstants.Backend.useLocalOnly {
            authState = .authenticated(userId: normalizedUserId)
            if !wasAlreadyAuthenticated {
                refreshOnboardingState(userId: normalizedUserId, context: context)
            }
            return
        }

        if wasAlreadyAuthenticated {
            authState = .authenticated(userId: normalizedUserId)
            return
        }

        authState = .loading

        await refreshSubscriptionState(for: normalizedUserId)

        let remoteProfile = await SupabaseManager.shared.fetchRemoteProfileSummary(userId: normalizedUserId)
        if !isPro, remoteProfile.isPro {
            isPro = true
        }

        authState = .authenticated(userId: normalizedUserId)

        if isPro {
            isRestoringFromCloud = true
            needsOnboarding = false
            pendingNavigation = .home
        } else if remoteProfile.exists {
            markOnboardingCompleted(for: normalizedUserId)
            needsOnboarding = false
            pendingNavigation = .home
        } else {
            refreshOnboardingState(userId: normalizedUserId, context: context)
        }
    }

    func setAuthenticated(userId: String, context: ModelContext) {
        let normalizedUserId = Self.normalizeUserId(userId)
        authState = .authenticated(userId: normalizedUserId)

        if AppConstants.Backend.useLocalOnly {
            refreshOnboardingState(userId: normalizedUserId, context: context)
        }
    }

    func applyCustomerInfo(_ info: CustomerInfo) {
        guard !UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.debugForcePro) else { return }

        let wasPro = isPro
        isPro = info.entitlements[AppConstants.RevenueCat.proEntitlementID]?.isActive == true

        guard isPro, !wasPro, authenticatedUserId != nil, needsOnboarding, !isRestoringFromCloud else { return }

        isRestoringFromCloud = true
        needsOnboarding = false
        pendingNavigation = .home
    }

    func finishCloudRestore(context: ModelContext) {
        guard let userId = authenticatedUserId else {
            isRestoringFromCloud = false
            return
        }

        isRestoringFromCloud = false
        refreshOnboardingState(userId: userId, context: context)
    }

    func finishOnboarding() {
        guard let userId = authenticatedUserId else { return }

        markOnboardingCompleted(for: userId)
        needsOnboarding = false
        pendingNavigation = .home
    }

    func signOut() {
        authState = .unauthenticated
        needsOnboarding = false
        isRestoringFromCloud = false
        isPro = false
        pendingNavigation = .auth
        WidgetDataPublisher.publishEmpty()

        Task {
            await PurchaseService.shared.logOutIfNeeded()
        }
    }

    private func refreshOnboardingState(userId: String, context: ModelContext) {
        let normalizedUserId = Self.normalizeUserId(userId)
        needsOnboarding = !Self.hasCompletedOnboarding(userId: normalizedUserId, context: context)
        pendingNavigation = needsOnboarding ? .onboarding : .home
    }

    private func refreshSubscriptionState(for userId: String) async {
        applyDebugProOverride()
        guard !UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.debugForcePro) else { return }

        if PurchaseService.shared.isConfigured {
            isPro = await PurchaseService.shared.bootstrapSubscription(for: userId)
        }
    }

    private func markOnboardingCompleted(for userId: String) {
        let normalizedUserId = Self.normalizeUserId(userId)
        UserDefaults.standard.set(
            true,
            forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: normalizedUserId)
        )
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
    }

    private static func normalizeUserId(_ userId: String) -> String {
        userId.lowercased()
    }

    private static func hasCompletedOnboarding(userId: String, context: ModelContext) -> Bool {
        let normalizedUserId = normalizeUserId(userId)

        for keyUserId in Set([normalizedUserId, userId]) {
            if UserDefaults.standard.bool(
                forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: keyUserId)
            ) {
                if keyUserId != normalizedUserId {
                    UserDefaults.standard.set(
                        true,
                        forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: normalizedUserId)
                    )
                }
                return true
            }
        }

        if SwiftDataStack.shared.userProfileExists(userId: normalizedUserId, context: context) {
            UserDefaults.standard.set(
                true,
                forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: normalizedUserId)
            )
            return true
        }

        if SwiftDataStack.shared.hasReturningUserData(userId: normalizedUserId, context: context) {
            UserDefaults.standard.set(
                true,
                forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: normalizedUserId)
            )
            return true
        }

        return false
    }

    func setAuthError(_ message: String) {
        authState = .error(message)
    }

    func requireUpgrade(for trigger: UpgradeTrigger) {
        pendingNavigation = .upgrade(trigger)
    }

    func clearPendingNavigation() {
        pendingNavigation = .none
    }

    func clearPendingWorkoutBuilder() {
        pendingWorkoutBuilder = nil
    }

    var authenticatedUserId: String? {
        if case let .authenticated(userId) = authState {
            return userId
        }
        return nil
    }
}
