import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AppState {
    var authState: AuthState = .loading
    var needsOnboarding = false
    var isPro = false
    var isRestoringFromCloud = false
    var pendingNavigation: PendingNavigation = .none
    var pendingWorkoutBuilder: PendingWorkoutBuilder?

    func setAuthenticated(userId: String, context: ModelContext) {
        authState = .authenticated(userId: userId)

        if AppConstants.Backend.useLocalOnly {
            refreshOnboardingState(userId: userId, context: context)
        } else {
            isRestoringFromCloud = true
        }
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

        UserDefaults.standard.set(
            true,
            forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: userId)
        )
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)

        needsOnboarding = false
        pendingNavigation = .home
    }

    func signOut() {
        authState = .unauthenticated
        needsOnboarding = false
        isRestoringFromCloud = false
        isPro = false
        pendingNavigation = .auth
    }

    private func refreshOnboardingState(userId: String, context: ModelContext) {
        needsOnboarding = !Self.hasCompletedOnboarding(userId: userId, context: context)
        pendingNavigation = needsOnboarding ? .onboarding : .home
    }

    private static func hasCompletedOnboarding(userId: String, context: ModelContext) -> Bool {
        if UserDefaults.standard.bool(
            forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: userId)
        ) {
            return true
        }

        if SwiftDataStack.shared.userProfileExists(userId: userId, context: context) {
            UserDefaults.standard.set(
                true,
                forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: userId)
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
