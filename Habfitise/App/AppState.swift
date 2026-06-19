import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AppState {
    var authState: AuthState = .loading
    var needsOnboarding = false
    var isPro = false
    var pendingNavigation: PendingNavigation = .none
    var pendingWorkoutBuilder: PendingWorkoutBuilder?

    func setAuthenticated(userId: String, context: ModelContext) {
        authState = .authenticated(userId: userId)
        needsOnboarding = !Self.hasCompletedOnboarding(userId: userId, context: context)
        pendingNavigation = needsOnboarding ? .onboarding : .home
    }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
        needsOnboarding = false
        pendingNavigation = .home
    }

    func signOut() {
        authState = .unauthenticated
        needsOnboarding = false
        isPro = false
        pendingNavigation = .auth
    }

    private static func hasCompletedOnboarding(userId: String, context: ModelContext) -> Bool {
        if UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding) {
            return true
        }
        // Migrate existing users who completed onboarding before the flag existed.
        if SwiftDataStack.shared.userProfileExists(userId: userId, context: context) {
            UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
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
